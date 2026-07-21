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

-- Which discovery backend M.list would pick for this machine (mirrors the
-- fd > rg > git > lua priority in connectors/filesystem.lua).
local function active_backend()
  if vim.fn.executable("fd") == 1 then
    return "fd"
  elseif vim.fn.executable("rg") == 1 then
    return "rg"
  elseif vim.fn.executable("git") == 1 then
    return "git"
  end
  return "lua"
end

-- Best-effort launcher version via `prompt-nvim --version`; never blocks or
-- errors if the launcher is absent or unparseable.
local function launcher_version()
  if vim.fn.executable("prompt-nvim") ~= 1 then
    return "(not on PATH)"
  end
  local ok, res = pcall(function()
    return vim.system({ "prompt-nvim", "--version" }, { text = true }):wait(1000)
  end)
  if not ok or not res or res.code ~= 0 then
    return "(unknown)"
  end
  return (vim.trim((res.stdout or "")):gsub("^prompt%-nvim%s+", ""))
end

-- Unique source names that the current target's triggers would activate.
local function target_sources(target)
  local def = target and require("prompt.registry").get_target(target)
  if not def or type(def.triggers) ~= "table" then
    return {}
  end
  local seen, names = {}, {}
  for _, trig in pairs(def.triggers) do
    for _, name in ipairs((type(trig) == "table" and trig.sources) or {}) do
      if not seen[name] then
        seen[name] = true
        table.insert(names, name)
      end
    end
  end
  table.sort(names)
  return names
end

-- Session-oriented :PromptInfo report. Never includes buffer/prompt content.
function M.info(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local session = require("prompt.session").get(bufnr)
  local target = require("prompt.target").resolve(bufnr)

  local mode
  if session and session.remote then
    mode = "remote bridge"
  elseif session and session.bridge then
    mode = "fresh bridge"
  elseif session then
    mode = "plain session"
  else
    mode = "none"
  end

  local lines = {
    "Session:       " .. tostring(session and session.id or "(none)"),
    "State:         " .. tostring(session and session.state or "-"),
    "Buffer:        " .. tostring(bufnr),
    "Target:        " .. tostring(target),
    "Launch cwd:    " .. tostring(session and session.launch_cwd or vim.fn.getcwd()),
    "Detected root: "
      .. tostring(session and session.root or require("prompt.root").detect(vim.fn.getcwd())),
    "Mode:          " .. mode,
    "Backend:       " .. active_backend(),
    "Launcher:      " .. launcher_version(),
    "Plugin:        " .. tostring(require("prompt.version").version),
    "Sources:       "
      .. (next(target_sources(target)) and table.concat(target_sources(target), ", ") or "(none)"),
  }
  return table.concat(lines, "\n")
end

function M.create()
  vim.api.nvim_create_user_command("PromptNew", function(opts)
    vim.cmd("enew")
    local target = (opts.args ~= "" and opts.args) or require("prompt.target").resolve(0)
    require("prompt.buffer").attach(0, target)
    require("prompt.log").info("target: " .. tostring(target))
  end, {
    nargs = "?",
    complete = complete_targets,
    desc = "Prompt: create a new scratch buffer",
    force = true,
  })

  vim.api.nvim_create_user_command("PromptAttach", function(opts)
    local target = (opts.args ~= "" and opts.args) or require("prompt.target").resolve(0)
    if target and not require("prompt.registry").has(target) then
      vim.notify("[prompt] unknown target: " .. tostring(target), vim.log.levels.WARN)
      return
    end
    require("prompt.buffer").attach(0, target)
  end, {
    nargs = "?",
    complete = complete_targets,
    desc = "Prompt: attach current buffer",
    force = true,
  })

  vim.api.nvim_create_user_command("PromptDetach", function()
    require("prompt.buffer").detach(0)
  end, { nargs = 0, desc = "Prompt: detach current buffer", force = true })

  vim.api.nvim_create_user_command("PromptTarget", function(opts)
    if opts.args == "" then
      vim.notify(
        "[prompt] target: " .. tostring(require("prompt.target").resolve(0)),
        vim.log.levels.INFO
      )
      return
    end

    if not require("prompt.registry").has(opts.args) then
      vim.notify("[prompt] unknown target: " .. opts.args, vim.log.levels.WARN)
      return
    end

    vim.b.prompt_target = opts.args
    vim.notify("[prompt] target set to " .. opts.args, vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = complete_targets,
    desc = "Prompt: get or set current buffer target",
    force = true,
  })

  vim.api.nvim_create_user_command("PromptReturn", function()
    require("prompt.bridge").return_prompt(0)
  end, { nargs = 0, desc = "Prompt: save and return to caller", force = true })

  vim.api.nvim_create_user_command("PromptCancel", function()
    require("prompt.bridge").cancel(0)
  end, { nargs = 0, desc = "Prompt: cancel and restore", force = true })

  vim.api.nvim_create_user_command("PromptInfo", function()
    vim.notify(require("prompt.commands").info(0), vim.log.levels.INFO)
  end, { nargs = 0, desc = "Prompt: show session info", force = true })

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
