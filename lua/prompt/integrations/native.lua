local M = {}

-- Tracks the cancel function for the most recently issued completion request
-- so a new request (from either entry point below) aborts any still-running
-- source work (e.g. a filesystem scan) instead of leaving it to finish unused.
local pending_cancel

local function cancel_pending()
  if pending_cancel then
    pcall(pending_cancel)
    pending_cancel = nil
  end
end

function M.complete_insert()
  if not require("prompt.buffer").is_attached(0) then
    return
  end

  local ctx = require("prompt.context").build()
  local bufnr = ctx.bufnr
  local captured_target = ctx.target
  local captured_row = ctx.row

  cancel_pending()
  pending_cancel = require("prompt.completion").complete(ctx, function(ranked)
    pending_cancel = nil
    if not ranked or #ranked == 0 then
      return
    end
    -- Drop stale results: buffer gone, target changed, or cursor moved away
    -- from the query region since this request was issued.
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if ctx.target ~= captured_target then
      return
    end
    local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    if not ok then
      return
    end
    local row, col = cursor[1], cursor[2]
    local query_col = ctx.query_col or ctx.col
    if row ~= captured_row or col < query_col then
      return
    end

    local complete_col = query_col + 1
    local items = {}
    for _, c in ipairs(ranked) do
      table.insert(items, {
        word = c.insert_text,
        abbr = c.label,
        menu = c.detail or c.source,
        kind = (c.kind or ""):sub(1, 1):upper(),
        dup = 0,
        icase = 1,
      })
    end

    pcall(vim.fn.complete, complete_col, items)
  end)
end

function M.complete_select()
  if not require("prompt.buffer").is_attached(0) then
    vim.notify("[prompt] buffer not attached", vim.log.levels.WARN)
    return
  end

  local ctx = require("prompt.context").build()
  local bufnr = ctx.bufnr
  local winid = ctx.winid
  local captured_target = ctx.target
  local captured_row = ctx.row

  cancel_pending()
  pending_cancel = require("prompt.completion").complete(ctx, function(ranked)
    pending_cancel = nil
    if not ranked or #ranked == 0 then
      vim.notify("[prompt] no completions", vim.log.levels.INFO)
      return
    end
    -- Drop stale results: buffer gone, or target changed since this request
    -- was issued. The query region is re-validated right before the actual
    -- buffer edit below, since vim.ui.select is itself async and the cursor
    -- may move further while the picker is open.
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if ctx.target ~= captured_target then
      return
    end

    vim.ui.select(ranked, {
      prompt = "Prompt completion",
      format_item = function(c)
        return c.label .. (c.detail and ("  " .. c.detail) or "")
      end,
    }, function(choice)
      if not choice then
        return
      end
      -- Re-validate the region right before editing: vim.ui.select is async,
      -- so the buffer/window/cursor may have changed since the request was
      -- issued or since the ranked results arrived.
      if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winid) then
        return
      end
      local ok, cursor = pcall(vim.api.nvim_win_get_cursor, winid)
      if not ok then
        return
      end
      local row, col = cursor[1], cursor[2]
      local query_col = ctx.query_col or ctx.col
      if row ~= captured_row or col < query_col then
        return
      end
      vim.api.nvim_buf_set_text(bufnr, row - 1, query_col, row - 1, col, { choice.insert_text })
      vim.api.nvim_win_set_cursor(winid, { row, query_col + #choice.insert_text })
    end)
  end)
end

return M
