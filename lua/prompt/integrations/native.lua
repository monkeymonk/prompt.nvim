local M = {}

function M.complete_insert()
  if not require("prompt.buffer").is_attached(0) then
    return
  end

  local ctx = require("prompt.context").build()
  require("prompt.completion").complete(ctx, function(ranked)
    if not ranked or #ranked == 0 then
      return
    end

    local col = (ctx.query_col or ctx.col) + 1
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

    pcall(vim.fn.complete, col, items)
  end)
end

function M.complete_select()
  if not require("prompt.buffer").is_attached(0) then
    vim.notify("[prompt] buffer not attached", vim.log.levels.WARN)
    return
  end

  local ctx = require("prompt.context").build()
  require("prompt.completion").complete(ctx, function(ranked)
    if not ranked or #ranked == 0 then
      vim.notify("[prompt] no completions", vim.log.levels.INFO)
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
      vim.api.nvim_buf_set_text(ctx.bufnr, ctx.row - 1, ctx.query_col, ctx.row - 1, ctx.col, { choice.insert_text })
      vim.api.nvim_win_set_cursor(ctx.winid, { ctx.row, ctx.query_col + #choice.insert_text })
    end)
  end)
end

return M
