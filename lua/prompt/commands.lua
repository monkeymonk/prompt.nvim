local M = {}

local function complete_targets(arglead)
  local matches = {}
  for _, def in ipairs(require("prompt.registry").list_targets()) do
    if def.name:sub(1, #arglead) == arglead then
      table.insert(matches, def.name)
    end
  end
  return matches
end

function M.create()
  vim.api.nvim_create_user_command("PromptNew", function(opts)
    vim.cmd("enew")
    local target = (opts.args ~= "" and opts.args) or require("prompt.target").resolve(0)
    require("prompt.buffer").attach(0, target)
    require("prompt.log").info("target: " .. tostring(target))
  end, { nargs = "?", complete = complete_targets, desc = "Prompt: create a new scratch buffer", force = true })

  vim.api.nvim_create_user_command("PromptAttach", function(opts)
    local target = (opts.args ~= "" and opts.args) or require("prompt.target").resolve(0)
    if target and not require("prompt.registry").has(target) then
      vim.notify("[prompt] unknown target: " .. tostring(target), vim.log.levels.WARN)
      return
    end
    require("prompt.buffer").attach(0, target)
  end, { nargs = "?", complete = complete_targets, desc = "Prompt: attach current buffer", force = true })

  vim.api.nvim_create_user_command("PromptDetach", function()
    require("prompt.buffer").detach(0)
  end, { nargs = 0, desc = "Prompt: detach current buffer", force = true })

  vim.api.nvim_create_user_command("PromptTarget", function(opts)
    if opts.args == "" then
      vim.notify("[prompt] target: " .. tostring(require("prompt.target").resolve(0)), vim.log.levels.INFO)
      return
    end

    if not require("prompt.registry").has(opts.args) then
      vim.notify("[prompt] unknown target: " .. opts.args, vim.log.levels.WARN)
      return
    end

    vim.b.prompt_target = opts.args
    vim.notify("[prompt] target set to " .. opts.args, vim.log.levels.INFO)
  end, { nargs = "?", complete = complete_targets, desc = "Prompt: get or set current buffer target", force = true })

  vim.api.nvim_create_user_command("PromptReturn", function()
    require("prompt.bridge").return_prompt(0)
  end, { nargs = 0, desc = "Prompt: save and return to caller", force = true })

  vim.api.nvim_create_user_command("PromptCancel", function()
    require("prompt.bridge").cancel(0)
  end, { nargs = 0, desc = "Prompt: cancel and restore", force = true })

  vim.api.nvim_create_user_command("PromptInfo", function()
    local bridge = require("prompt.bridge")
    local report = table.concat({
      "target: " .. tostring(require("prompt.target").resolve(0)),
      "attached: " .. tostring(require("prompt.buffer").is_attached(0)),
      "bridge: " .. tostring(bridge.is_bridge_buffer(0)),
      "original_path: " .. tostring(vim.b.prompt_original_path or "(none)"),
      "bridge_mode_env: " .. tostring(bridge.in_bridge_mode()),
    }, "\n")
    vim.notify(report, vim.log.levels.INFO)
  end, { nargs = 0, desc = "Prompt: show buffer info", force = true })

  vim.api.nvim_create_user_command("PromptHealth", function()
    vim.cmd("checkhealth prompt")
  end, { nargs = 0, desc = "Prompt: run health checks", force = true })

  vim.api.nvim_create_user_command("PromptComplete", function()
    require("prompt.integrations.native").complete_select()
  end, { nargs = 0, desc = "Prompt: complete at cursor", force = true })

  vim.api.nvim_create_user_command("PromptRefresh", function()
    require("prompt.cache").clear()
    require("prompt.root").clear()
    vim.notify("[prompt] caches cleared", vim.log.levels.INFO)
  end, { nargs = 0, desc = "Prompt: clear caches", force = true })
end

return M
