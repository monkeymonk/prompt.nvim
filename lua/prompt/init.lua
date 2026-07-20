local M = {}

M._setup_done = false

local function register_builtins()
  for _, name in ipairs({ "claude", "codex", "gemini", "opencode", "pi" }) do
    require("prompt.registry").register_target(name, require("prompt.targets." .. name), { override = true })
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
