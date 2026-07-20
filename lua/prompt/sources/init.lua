local M = {}

local sources = {}

function M.register(name, source)
  sources[name] = source
end

function M.get(name)
  return sources[name]
end

function M.has(name)
  return sources[name] ~= nil
end

function M.list()
  local names = {}
  for name in pairs(sources) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

function M.register_builtins()
  M.register("files", require("prompt.sources.files"))
  M.register("directories", require("prompt.sources.directories"))
  M.register("shell", require("prompt.sources.shell"))

  local make = require("prompt.sources.connector_source").make
  M.register("claude_commands", make("claude", "commands"))
  M.register("claude_skills", make("claude", "skills"))

  M.register("codex_commands", make("codex", "commands"))
  M.register("codex_skills", make("codex", "skills"))
  M.register("gemini_commands", make("gemini", "commands"))
  M.register("gemini_skills", make("gemini", "skills"))
  M.register("gemini_agents", make("gemini", "agents"))
  M.register("opencode_commands", make("opencode", "commands"))
  M.register("opencode_agents", make("opencode", "agents"))
  M.register("pi_commands", make("pi", "commands"))
  M.register("pi_skills", make("pi", "skills"))
  M.register("pi_prompts", make("pi", "prompts"))
end

return M
