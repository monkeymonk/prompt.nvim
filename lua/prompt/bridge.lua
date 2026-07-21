local M = {}

local function nonempty(s)
  if s and s ~= "" then
    return s
  end
  return nil
end

-- Only used to detect a fresh (VimEnter-driven) bridge process; existing-
-- server sessions are identified purely by the session table (see below).
function M.in_bridge_mode()
  return vim.env.PROMPT_NVIM_BRIDGE == "1"
end

function M.is_bridge_buffer(bufnr)
  local session = require("prompt.session").get(bufnr or 0)
  return session ~= nil and session.bridge == true
end

-- M.attach(bufnr) — marks the (already-created, see buffer.attach) session
-- as a bridge session and resolves its raw-byte backup path: fresh processes
-- get it from PROMPT_NVIM_BACKUP (exported by the launcher); remote sessions
-- already carry it on the session (set by `prompt.remote` from the RPC spec).
function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local session_mod = require("prompt.session")
  local session = session_mod.get(bufnr)
  if not session then
    return
  end

  session.bridge = true
  if not session.backup_path then
    session.backup_path = nonempty(vim.env.PROMPT_NVIM_BACKUP)
  end
  vim.b[bufnr].prompt_session = session

  M.setup_keymaps(bufnr)
end

function M.setup_keymaps(bufnr)
  local km = require("prompt.config").get().keymaps

  if km.return_prompt then
    vim.keymap.set({ "n", "i" }, km.return_prompt, function()
      M.return_prompt(bufnr)
    end, { buffer = bufnr, desc = "Prompt: save and return", silent = true })
  end

  if km.cancel_prompt then
    vim.keymap.set({ "n" }, km.cancel_prompt, function()
      M.cancel(bufnr)
    end, { buffer = bufnr, desc = "Prompt: cancel and restore", silent = true })
  end
end

-- Closes the prompt buffer/process without touching its content.
-- `bang=true` forces the close even though the buffer is modified (used by
-- cancel paths, where the edits must be discarded, never written).
local function close_buffer(bufnr, session, bang)
  if session and session.remote then
    -- Target THIS buffer explicitly: a bare `:bdelete` would close whatever
    -- buffer is current, which is not necessarily `bufnr` (multiple concurrent
    -- remote sessions, or the VimLeavePre cleanup loop iterating buffers).
    pcall(vim.api.nvim_buf_delete, bufnr, { force = bang == true })
  else
    vim.cmd("quitall" .. (bang and "!" or ""))
  end
end

-- Write `bufnr` regardless of which buffer is current (same reasoning as
-- close_buffer). Returns true on success.
local function write_buffer(bufnr)
  return pcall(vim.api.nvim_buf_call, bufnr, function()
    vim.cmd("silent write")
  end)
end

function M.return_prompt(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local session_mod = require("prompt.session")
  if not session_mod.is_active(bufnr) then
    return
  end

  session_mod.set_state(bufnr, "returning")

  local ok = write_buffer(bufnr)
  if not ok then
    require("prompt.log").warn("failed to write buffer")
    session_mod.set_state(bufnr, "failed")
    return
  end

  if not require("prompt.config").get().bridge.close_on_return then
    return
  end

  local session = session_mod.get(bufnr)
  session_mod.set_state(bufnr, "closed")
  close_buffer(bufnr, session, false)
end

-- Byte-preserving restore: copies the raw backup bytes over the original
-- file (no buffer serialization), so CRLF/BOM/final-newline/encoding survive
-- exactly. Returns true on a successful raw restore.
local function restore_from_backup(bufnr, session)
  if session and session.backup_path and session.original_path then
    if vim.uv.fs_copyfile(session.backup_path, session.original_path) then
      return true
    end
  end
  require("prompt.log").warn(
    "prompt: no raw backup available for cancel; original file left untouched (byte-fidelity not re-verified)"
  )
  return false
end

function M.cancel(bufnr, strategy)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local session_mod = require("prompt.session")
  if not session_mod.is_active(bufnr) then
    return
  end
  strategy = strategy or require("prompt.config").get().bridge.cancel_strategy or "restore"

  session_mod.set_state(bufnr, "cancelling")
  local session = session_mod.get(bufnr)

  if strategy == "restore" then
    restore_from_backup(bufnr, session)
    session_mod.set_state(bufnr, "closed")
    close_buffer(bufnr, session, true)
  elseif strategy == "delete" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })
    local ok = write_buffer(bufnr)
    if not ok then
      require("prompt.log").warn("failed to write buffer")
      session_mod.set_state(bufnr, "failed")
      return
    end
    if require("prompt.config").get().bridge.close_on_return then
      session_mod.set_state(bufnr, "closed")
      close_buffer(bufnr, session, false)
    end
  elseif strategy == "error-exit" then
    session_mod.set_state(bufnr, "closed")
    pcall(vim.cmd, "cquit")
  else
    require("prompt.log").warn("unknown cancel strategy: " .. tostring(strategy))
    restore_from_backup(bufnr, session)
    session_mod.set_state(bufnr, "closed")
    close_buffer(bufnr, session, true)
  end
end

-- Settle a bridge buffer that is going away because the editor itself is
-- quitting (QuitPre/VimLeavePre). The quit is ALREADY in progress, so this must
-- NOT close/quit anything — it only decides the file's final bytes:
--   * modified buffer  -> a force-quit (:q!/:qa!) discarding unsaved edits:
--                         restore the original byte-for-byte (cancel semantics).
--   * unmodified buffer -> a clean quit of a saved/unchanged prompt (:wq/:x/ZZ/
--                         :qa): the on-disk file is what the user wants returned,
--                         so keep it and just close the session (return
--                         semantics). Restoring here would clobber the save.
-- State-guarded, so it is a no-op for a session already returned/cancelled via
-- the explicit commands.
function M.finalize_on_quit(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local session_mod = require("prompt.session")
  if not session_mod.is_active(bufnr) then
    return
  end
  local session = session_mod.get(bufnr)

  if vim.bo[bufnr].modified then
    session_mod.set_state(bufnr, "cancelling")
    restore_from_backup(bufnr, session)
    session_mod.set_state(bufnr, "closed")
  else
    session_mod.set_state(bufnr, "returning")
    session_mod.set_state(bufnr, "closed")
  end
end

return M
