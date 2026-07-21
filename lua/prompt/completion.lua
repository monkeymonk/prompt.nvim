local M = {}

-- Tracks the most recently issued request id per buffer so late results from a
-- superseded request can be dropped (see `finish()` below).
local current_request = {}

local seq = 0
local function next_id()
  seq = seq + 1
  return seq
end

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

--- C2: prefer the session's detected root/launch cwd when the buffer belongs
--- to an active prompt session (set by `prompt.session`, owned by another work
--- package). Falls back to the context's existing root for non-session
--- buffers, or if `prompt.session` isn't available yet.
local function apply_session_root(ctx)
  local ok, session = pcall(require, "prompt.session")
  if not ok or type(session) ~= "table" or type(session.get) ~= "function" then
    return
  end
  local ok_get, sess = pcall(session.get, ctx.bufnr)
  if not ok_get or not sess then
    return
  end
  if sess.root then
    ctx.root = sess.root
  end
end

function M.complete(ctx, callback)
  local noop_cancel = function() end

  local def = ctx.target and require("prompt.registry").get_target(ctx.target)
  if not def then
    callback({})
    return noop_cancel
  end

  local parsed =
    require("prompt.trigger").parse({ before_cursor = ctx.before_cursor, target = def })
  if not parsed then
    callback({})
    return noop_cancel
  end

  local cfg = require("prompt.config").get()
  if #parsed.query < (cfg.completion.min_query_length or 0) then
    callback({})
    return noop_cancel
  end

  ctx.trigger = parsed.trigger
  ctx.query = parsed.query
  ctx.start_col = parsed.start_col
  ctx.query_col = parsed.query_col
  ctx.sources = parsed.sources
  ctx._max_results = cfg.completion.max_results

  apply_session_root(ctx)
  ctx._open_buffers = open_buffers_map(ctx.root)

  local active = {}
  for _, name in ipairs(parsed.sources) do
    local s = require("prompt.sources").get(name)
    if s and (s.enabled == nil or s.enabled(ctx)) then
      table.insert(active, { name = name, source = s })
    end
  end

  if #active == 0 then
    callback({})
    return noop_cancel
  end

  local log = require("prompt.log")

  local request = {
    id = next_id(),
    bufnr = ctx.bufnr,
    cancelled = false,
    pending = {},
  }
  current_request[ctx.bufnr] = request.id

  local collected = {}
  local remaining = #active
  local request_start = vim.uv.hrtime()

  local function is_stale()
    return request.cancelled
      or current_request[request.bufnr] ~= request.id
      or not vim.api.nvim_buf_is_valid(request.bufnr)
  end

  local function finish()
    if is_stale() then
      return
    end
    local normalized = require("prompt.candidate").normalize_all(collected, ctx)
    local ranked = require("prompt.ranking").sort(normalized, ctx)
    local total_ms = (vim.uv.hrtime() - request_start) / 1e6
    log.debug(
      string.format("completion request %d: total: %dms %d items", request.id, total_ms, #collected)
    )
    vim.schedule(function()
      if is_stale() then
        return
      end
      callback(ranked)
    end)
  end

  for i, entry in ipairs(active) do
    local name, s = entry.name, entry.source
    local fired = false
    local source_start = vim.uv.hrtime()

    local function done(items)
      if fired then
        return
      end
      fired = true
      request.pending[i] = nil

      local elapsed_ms = (vim.uv.hrtime() - source_start) / 1e6
      local count = 0
      for _, it in ipairs(items or {}) do
        if count >= cfg.completion.max_items_per_source then
          break
        end
        table.insert(collected, it)
        count = count + 1
      end
      log.debug(
        string.format(
          "completion request %d: %s: %dms %d items",
          request.id,
          name,
          elapsed_ms,
          count
        )
      )

      remaining = remaining - 1
      if remaining == 0 then
        finish()
      end
    end

    vim.defer_fn(function()
      if not fired then
        log.debug(string.format("completion request %d: %s: source timeout", request.id, name))
        done({})
      end
    end, cfg.completion.source_timeout_ms)

    local ok, cancel_or_err = xpcall(function()
      return s.complete(ctx, done)
    end, debug.traceback)

    if ok then
      if type(cancel_or_err) == "function" then
        request.pending[i] = cancel_or_err
      end
    else
      log.debug(
        string.format(
          "completion request %d: %s: error: %s",
          request.id,
          name,
          tostring(cancel_or_err)
        )
      )
      done({})
    end
  end

  return function()
    request.cancelled = true
    for _, c in pairs(request.pending) do
      pcall(c)
    end
  end
end

return M
