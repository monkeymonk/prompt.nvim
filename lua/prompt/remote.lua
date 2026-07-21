-- Existing-server RPC entry point.
--
-- Neovim does NOT implement `--remote-wait` (E5600), so the launcher cannot
-- block on the client the way `nvim --remote-wait` would. Instead the launcher
-- (`bin/prompt-nvim --server ...`) drives this module over `--remote-expr`:
--
--   1. `open_from_file(spec_json_path)` — registers the session metadata, opens
--      the prompt file in the already-running server (which fires BufReadPost ->
--      the autocmd in init.lua -> `attach_pending`, giving the buffer its
--      session), and returns 1 on success.
--   2. the launcher then polls `is_open(session_id)` until it returns 0, i.e.
--      the user returned or cancelled and the buffer closed. That poll loop is
--      what replaces `--remote-wait`.
--
-- Session metadata travels through a temp JSON file (not an inline
-- `--remote-expr` literal) so target/path characters never have to survive
-- shell -> VimL -> Lua escaping.
local M = {}

-- normalized-file -> spec, consumed when the buffer is opened/attached.
M.pending = {}
-- session_id -> normalized-file, so the launcher can poll by its own
-- (quote-free) session id rather than by an arbitrary file path.
M.by_session = {}

local function normalize(file)
  return vim.fs.normalize(vim.fn.fnamemodify(file, ":p"))
end

local function nonempty(s)
  if s and s ~= "" then
    return s
  end
  return nil
end

-- M.register(spec) — spec = { file, target, cwd, session_id, bridge, backup }
function M.register(spec)
  spec = spec or {}
  if type(spec.file) ~= "string" or spec.file == "" then
    require("prompt.log").warn("prompt.remote: register() called without a file")
    return nil
  end
  local key = normalize(spec.file)
  M.pending[key] = spec
  if nonempty(spec.session_id) then
    M.by_session[spec.session_id] = key
  end
  return spec
end

-- Reads a JSON-encoded spec written by the launcher and registers it. Returns
-- the spec on success, nil otherwise.
function M.register_from_file(path)
  if type(path) ~= "string" or path == "" then
    require("prompt.log").warn("prompt.remote: register_from_file() called without a path")
    return nil
  end

  local ok_read, content = pcall(function()
    local f = assert(io.open(path, "r"))
    local data = f:read("*a")
    f:close()
    return data
  end)
  if not ok_read then
    require("prompt.log").warn("prompt.remote: failed to read spec file: " .. tostring(path))
    return nil
  end

  local ok_decode, spec = pcall(vim.json.decode, content)
  if not ok_decode or type(spec) ~= "table" then
    require("prompt.log").warn("prompt.remote: failed to decode spec file: " .. tostring(path))
    return nil
  end

  return M.register(spec)
end

-- M.is_pending(bufnr) -> boolean — cheap membership check, safe to call for
-- every buffer read (only registered prompt files match).
function M.is_pending(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end
  return M.pending[normalize(name)] ~= nil
end

-- Builds the session + bridge attachment for a spec against an already-open
-- buffer. Shared by the BufReadPost/BufAdd handler and `M.open_from_file`.
local function attach_buffer(bufnr, spec)
  require("prompt.buffer").attach(bufnr, spec.target, {
    id = spec.session_id,
    launch_cwd = spec.cwd,
    root = require("prompt.root").detect(spec.cwd),
    remote = true,
    backup_path = nonempty(spec.backup),
    original_path = vim.api.nvim_buf_get_name(bufnr),
  })

  if spec.bridge then
    require("prompt.bridge").attach(bufnr)
  end

  require("prompt.highlight").attach(bufnr)
end

-- M.attach_pending(bufnr) -> boolean — if `bufnr` matches a pending spec,
-- consume it and attach. Called by the BufReadPost/BufAdd autocmd.
function M.attach_pending(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end

  local key = normalize(name)
  local spec = M.pending[key]
  if not spec then
    return false
  end

  M.pending[key] = nil
  attach_buffer(bufnr, spec)
  return true
end

-- M.open_from_file(spec_json_path) -> 1|0 — register the spec and open its
-- prompt file in this server. Opening fires BufReadPost, which attaches the
-- session; as a fallback we attach directly if the autocmd did not run. Returns
-- 1 once the buffer exists and is attached, 0 on any failure. Returns a number
-- (not a Lua boolean) so `--remote-expr` prints a clean "1"/"0".
function M.open_from_file(spec_json_path)
  local spec = M.register_from_file(spec_json_path)
  if not spec then
    return 0
  end

  if not require("prompt")._setup_done then
    require("prompt").setup({})
  end

  local ok = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(spec.file))
  end)
  if not ok then
    return 0
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not require("prompt.session").get(bufnr) then
    M.attach_pending(bufnr)
  end

  return require("prompt.session").get(bufnr) and 1 or 0
end

-- M.is_open(session_id) -> 1|0 — the launcher polls this to emulate
-- --remote-wait: 1 while the session's buffer is still open (not closed), 0
-- once the user has returned/cancelled and it has gone away.
function M.is_open(session_id)
  local file = M.by_session[session_id]
  if not file then
    return 0
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and normalize(vim.api.nvim_buf_get_name(bufnr)) == file then
      local s = require("prompt.session").get(bufnr)
      if s and s.state ~= "closed" then
        return 1
      end
    end
  end
  return 0
end

-- M.open(spec) — in-process convenience (tests / non-launcher callers): register
-- and attach immediately if the file is already open in a loaded buffer.
function M.open(spec)
  M.register(spec)

  local key = normalize(spec.file)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and normalize(vim.api.nvim_buf_get_name(bufnr)) == key then
      M.attach_pending(bufnr)
      break
    end
  end
end

return M
