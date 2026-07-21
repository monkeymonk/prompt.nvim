local M = {}

local connectors = {}

M.NAME_PATTERN = "^[a-z0-9_-]+$"

local VALID_STABILITY = { stable = true, experimental = true }

-- #27: validate a connector definition at registration time. Returns an error
-- string naming the offending field, or nil if the definition is valid.
local function validate(name, connector)
  if type(name) ~= "string" or not name:match(M.NAME_PATTERN) then
    return "invalid connector name: " .. tostring(name)
  end
  if type(connector) ~= "table" then
    return "connector definition for '" .. name .. "' must be a table"
  end
  if type(connector.discover) ~= "function" then
    return "connector '" .. name .. "' is missing a callable discover(kind, ctx, callback) function"
  end
  if connector.available ~= nil and type(connector.available) ~= "function" then
    return "connector '" .. name .. "' field 'available' must be a function"
  end
  if connector.meta ~= nil then
    if type(connector.meta) ~= "table" then
      return "connector '" .. name .. "' field 'meta' must be a table"
    end
    if connector.meta.stability ~= nil and not VALID_STABILITY[connector.meta.stability] then
      return "connector '" .. name .. "' field 'meta.stability' must be 'stable' or 'experimental'"
    end
    if
      connector.meta.version_command ~= nil and type(connector.meta.version_command) ~= "table"
    then
      return "connector '" .. name .. "' field 'meta.version_command' must be a table (argv list)"
    end
  end
  return nil
end

function M.register(name, connector, opts)
  local err = validate(name, connector)
  if err then
    error("prompt: " .. err)
  end

  if connectors[name] and not (opts and opts.override) then
    error("prompt: connector already registered: " .. name)
  end

  connectors[name] = connector
end

function M.unregister(name)
  connectors[name] = nil
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
  M.register("claude", require("prompt.connectors.claude"), { override = true })
  M.register("codex", require("prompt.connectors.codex"), { override = true })
  M.register("gemini", require("prompt.connectors.gemini"), { override = true })
  M.register("opencode", require("prompt.connectors.opencode"), { override = true })
  M.register("pi", require("prompt.connectors.pi"), { override = true })
end

return M
