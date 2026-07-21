local M = {}

local sources = {}

-- Validate a source at registration time (extension-API safety, #27): a broken
-- registration should error here with an actionable message, not fail silently
-- while the user is typing. Pass `opts.override = true` to replace an existing
-- source of the same name.
function M.register(name, source, opts)
  opts = opts or {}
  if type(name) ~= "string" or name == "" then
    error("prompt: source name must be a non-empty string", 2)
  end
  if type(source) ~= "table" then
    error(("prompt: source '%s' must be a table"):format(name), 2)
  end
  if type(source.complete) ~= "function" then
    error(("prompt: source '%s' must define a callable 'complete'"):format(name), 2)
  end
  if source.enabled ~= nil and type(source.enabled) ~= "function" then
    error(("prompt: source '%s' field 'enabled' must be a function"):format(name), 2)
  end
  if sources[name] ~= nil and not opts.override then
    error(
      ("prompt: source '%s' is already registered (pass override=true to replace)"):format(name),
      2
    )
  end
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
  local function reg(name, source)
    M.register(name, source, { override = true })
  end

  reg("files", require("prompt.sources.files"))
  reg("directories", require("prompt.sources.directories"))
  reg("shell", require("prompt.sources.shell"))

  local make = require("prompt.sources.connector_source").make
  reg("claude_commands", make("claude", "commands"))
  reg("claude_skills", make("claude", "skills"))

  reg("codex_commands", make("codex", "commands"))
  reg("codex_skills", make("codex", "skills"))
  reg("gemini_commands", make("gemini", "commands"))
  reg("gemini_skills", make("gemini", "skills"))
  reg("gemini_agents", make("gemini", "agents"))
  reg("opencode_commands", make("opencode", "commands"))
  reg("opencode_agents", make("opencode", "agents"))
  reg("pi_commands", make("pi", "commands"))
  reg("pi_skills", make("pi", "skills"))
  reg("pi_prompts", make("pi", "prompts"))
end

return M
