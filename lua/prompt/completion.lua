local M = {}

local function open_buffers_map(root)
  local ok, map = pcall(function()
    local m = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name ~= "" then
          local rel
          if root and name:sub(1, #root + 1) == root .. "/" then
            rel = name:sub(#root + 2)
          else
            rel = vim.fn.fnamemodify(name, ":.")
          end
          m[rel] = true
        end
      end
    end
    return m
  end)
  if ok then
    return map
  end
  return {}
end

function M.complete(ctx, callback)
  local def = ctx.target and require("prompt.registry").get_target(ctx.target)
  if not def then
    callback({})
    return
  end

  local parsed = require("prompt.trigger").parse({ before_cursor = ctx.before_cursor, target = def })
  if not parsed then
    callback({})
    return
  end

  local cfg = require("prompt.config").get()
  if #parsed.query < (cfg.completion.min_query_length or 0) then
    callback({})
    return
  end

  ctx.trigger = parsed.trigger
  ctx.query = parsed.query
  ctx.start_col = parsed.start_col
  ctx.query_col = parsed.query_col
  ctx.sources = parsed.sources
  ctx._max_results = cfg.completion.max_results
  ctx._open_buffers = open_buffers_map(ctx.root)

  local active = {}
  for _, name in ipairs(parsed.sources) do
    local s = require("prompt.sources").get(name)
    if s and (s.enabled == nil or s.enabled(ctx)) then
      table.insert(active, s)
    end
  end

  if #active == 0 then
    callback({})
    return
  end

  local collected = {}
  local remaining = #active

  local function finish()
    local normalized = require("prompt.candidate").normalize_all(collected, ctx)
    local ranked = require("prompt.ranking").sort(normalized, ctx)
    vim.schedule(function()
      callback(ranked)
    end)
  end

  for _, s in ipairs(active) do
    s.complete(ctx, function(items)
      for _, it in ipairs(items or {}) do
        table.insert(collected, it)
      end
      remaining = remaining - 1
      if remaining == 0 then
        finish()
      end
    end)
  end
end

return M
