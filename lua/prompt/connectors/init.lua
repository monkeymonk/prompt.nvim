local M = {}

local connectors = {}

function M.register(name, connector)
  connectors[name] = connector
end

function M.get(name)
  return connectors[name]
end

function M.has(name)
  return connectors[name] ~= nil
end

function M.list()
  local names = {}
  for name in pairs(connectors) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

function M.register_builtins()
  M.register("claude", require("prompt.connectors.claude"))
  M.register("codex", require("prompt.connectors.codex"))
  M.register("gemini", require("prompt.connectors.gemini"))
  M.register("opencode", require("prompt.connectors.opencode"))
  M.register("pi", require("prompt.connectors.pi"))
end

return M
