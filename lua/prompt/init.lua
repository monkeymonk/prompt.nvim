local M = {}

M._setup_done = false
M.api_version = 1

local function register_builtins()
  for _, name in ipairs({ "claude", "codex", "gemini", "opencode", "pi" }) do
    require("prompt.registry").register_target(
      name,
      require("prompt.targets." .. name),
      { override = true }
    )
  end
end

-- Register the VimEnter bridge auto-attach. Idempotent: the named augroup is
-- cleared on each call, so invoking this from both plugin/prompt.lua (real
-- package installs) and setup() (runtimepath-based local installs) is safe.
function M.setup_bridge()
  local group = vim.api.nvim_create_augroup("PromptBridge", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      local bridge = require("prompt.bridge")
      if not bridge.in_bridge_mode() then
        return
      end
      local prompt = require("prompt")
      if not prompt._setup_done then
        prompt.setup({})
      end
      if not require("prompt.config").get().bridge.enabled then
        return
      end
      local target = require("prompt.target").resolve(0)
      prompt.attach(0, target)
      if target then
        vim.notify("[prompt] bridge mode: " .. target, vim.log.levels.INFO)
      else
        vim.notify("[prompt] bridge mode: no target detected", vim.log.levels.WARN)
      end
    end,
  })
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("PromptCache", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = { "*/SKILL.md", "*/CLAUDE.md", "*/AGENTS.md", "*/GEMINI.md" },
    callback = function()
      require("prompt.cache").clear()
    end,
  })
end

-- Existing-server (--server) sessions: the launcher registers metadata via
-- `--remote-expr` (see `prompt.remote`) before it blocks on `--remote-wait`.
-- When that file's buffer is opened here, attach the session for it. Cheap
-- for every buffer read: `is_pending` is a plain table lookup that only
-- matches launcher-registered prompt files.
function M.setup_remote()
  local group = vim.api.nvim_create_augroup("PromptRemote", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufAdd" }, {
    group = group,
    callback = function(args)
      local remote = require("prompt.remote")
      if not remote.is_pending(args.buf) then
        return
      end
      if not M._setup_done then
        M.setup({})
      end
      remote.attach_pending(args.buf)
    end,
  })
end

-- Bridge session lifecycle: make sure quitting the editor (or the buffer
-- simply going away) never leaves a session dangling. On quit, a modified
-- buffer being force-quit (:q!/:qa!) restores the original byte-for-byte, while
-- a saved/clean quit (:wq/:x/:qa) keeps what was written (see
-- bridge.finalize_on_quit). BufUnload/BufDelete always brings the session to
-- "closed" and clears it. State-guarded, so it's a no-op for anything already
-- returned/cancelled/failed via the explicit commands.
function M.setup_lifecycle()
  local group = vim.api.nvim_create_augroup("PromptLifecycle", { clear = true })

  local function finalize_active_bridge_buffers()
    local session_mod = require("prompt.session")
    local bridge = require("prompt.bridge")
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if
        vim.api.nvim_buf_is_loaded(bufnr)
        and session_mod.is_active(bufnr)
        and bridge.is_bridge_buffer(bufnr)
      then
        -- Keep saved edits (:wq) and restore only on force-quit (:q!); never
        -- blindly cancel, which would discard a saved prompt.
        bridge.finalize_on_quit(bufnr)
      end
    end
  end

  vim.api.nvim_create_autocmd({ "QuitPre", "VimLeavePre" }, {
    group = group,
    callback = finalize_active_bridge_buffers,
  })

  vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
    group = group,
    callback = function(args)
      local session_mod = require("prompt.session")
      if session_mod.get(args.buf) then
        session_mod.set_state(args.buf, "closed")
        session_mod.clear(args.buf)
      end
    end,
  })
end

function M.setup(opts)
  local config = require("prompt.config").setup(opts)

  register_builtins()
  require("prompt.sources").register_builtins()
  require("prompt.connectors").register_builtins()

  for name, override_def in pairs(config.targets) do
    if type(override_def) == "table" and require("prompt.registry").has(name) then
      local existing = require("prompt.registry").get_target(name)
      local merged = vim.tbl_deep_extend("force", existing, override_def)
      require("prompt.registry").register_target(name, merged, { override = true })
    end
  end

  require("prompt.commands").create()
  M.setup_bridge()
  M.setup_remote()
  M.setup_lifecycle()
  M.setup_autocmds()
  require("prompt.highlight").setup_hl()

  M._setup_done = true
  return M
end

M.register_target = function(name, def, opts)
  return require("prompt.registry").register_target(name, def, opts)
end

M.unregister_target = function(name)
  return require("prompt.registry").unregister_target(name)
end

M.get_target = function(name)
  return require("prompt.registry").get_target(name)
end

M.list_targets = function()
  return require("prompt.registry").list_targets()
end

M.register_source = function(name, source)
  return require("prompt.sources").register(name, source)
end

M.register_connector = function(name, connector)
  return require("prompt.connectors").register(name, connector)
end

M.attach = function(bufnr, target)
  target = target or require("prompt.target").resolve(bufnr or 0)
  require("prompt.buffer").attach(bufnr, target)
  if require("prompt.bridge").in_bridge_mode() then
    require("prompt.bridge").attach(bufnr)
  end
  require("prompt.highlight").attach(bufnr or 0)
  return target
end

M.detach = function(bufnr)
  require("prompt.highlight").detach(bufnr or 0)
  return require("prompt.buffer").detach(bufnr)
end

return M
