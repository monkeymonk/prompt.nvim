-- Buffer-local session object (C1). This is the single source of truth for
-- a prompt buffer's lifecycle: `vim.b[bufnr].prompt_session`. Other packages
-- must only read it through `session.get(bufnr)` — never the legacy
-- `prompt_target`/`prompt_bridge`/`prompt_attached`/`prompt_original_path`/
-- `prompt_original_content` buffer vars, which this table subsumes.
local M = {}

-- Legal state transitions. Anything not listed here is rejected.
local transitions = {
  attached = { returning = true, cancelling = true, failed = true },
  returning = { closed = true },
  cancelling = { closed = true },
  failed = {},
  closed = {},
}

-- session.create(bufnr, spec) -> table
-- Builds and stores the session table for `bufnr`, state = "attached".
function M.create(bufnr, spec)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  spec = spec or {}

  local id = spec.id
  if not id or id == "" then
    id = string.format("%s-%x", "s", vim.uv.hrtime())
  end

  local session = {
    id = id,
    target = spec.target,
    launch_cwd = spec.launch_cwd,
    root = spec.root,
    bridge = spec.bridge == true,
    remote = spec.remote == true,
    original_path = spec.original_path,
    backup_path = spec.backup_path,
    state = "attached",
  }

  vim.b[bufnr].prompt_session = session
  return session
end

-- session.get(bufnr) -> table|nil
function M.get(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.b[bufnr].prompt_session
end

-- session.set_state(bufnr, state) -> boolean
-- Validated transition; returns false (and logs at debug) on an illegal one.
function M.set_state(bufnr, state)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local session = M.get(bufnr)
  if not session then
    return false
  end

  local allowed = transitions[session.state]
  if not allowed or not allowed[state] then
    require("prompt.log").debug(
      "session: illegal state transition " .. tostring(session.state) .. " -> " .. tostring(state)
    )
    return false
  end

  session.state = state
  vim.b[bufnr].prompt_session = session
  return true
end

-- session.is_active(bufnr) -> boolean
function M.is_active(bufnr)
  local session = M.get(bufnr)
  return session ~= nil and session.state == "attached"
end

-- session.clear(bufnr)
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.b[bufnr].prompt_session = nil
end

return M
