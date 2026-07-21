local M = {}

local targets = {}

M.NAME_PATTERN = "^[a-z0-9_-]+$"

-- #27: a trigger table is `{ [char] = { sources = {...}, line_start_only=,
-- word_query= } }`. Validate its shape at registration time — source names
-- can't be resolved yet (sources register after targets during setup(), and
-- custom sources may be registered later still), so this only checks
-- structure, not that the named sources exist.
local function validate_triggers(name, triggers)
  if triggers == nil then
    return nil
  end
  if type(triggers) ~= "table" then
    return "target '" .. name .. "' field 'triggers' must be a table"
  end
  for ch, spec in pairs(triggers) do
    if type(ch) ~= "string" or #ch ~= 1 then
      return "target '" .. name .. "' has an invalid trigger character: " .. tostring(ch)
    end
    if type(spec) ~= "table" then
      return "target '" .. name .. "' trigger '" .. ch .. "' must be a table"
    end
    if spec.sources ~= nil then
      if type(spec.sources) ~= "table" or #spec.sources == 0 then
        return "target '"
          .. name
          .. "' trigger '"
          .. ch
          .. "' field 'sources' must be a non-empty list"
      end
      for _, src in ipairs(spec.sources) do
        if type(src) ~= "string" or src == "" then
          return "target '"
            .. name
            .. "' trigger '"
            .. ch
            .. "' has a non-string entry in 'sources'"
        end
      end
    end
    if spec.line_start_only ~= nil and type(spec.line_start_only) ~= "boolean" then
      return "target '"
        .. name
        .. "' trigger '"
        .. ch
        .. "' field 'line_start_only' must be a boolean"
    end
    if spec.word_query ~= nil and type(spec.word_query) ~= "boolean" then
      return "target '" .. name .. "' trigger '" .. ch .. "' field 'word_query' must be a boolean"
    end
  end
  return nil
end

function M.register_target(name, def, opts)
  if type(name) ~= "string" or not name:match(M.NAME_PATTERN) then
    error("prompt: invalid target name: " .. tostring(name))
  end

  if targets[name] and not (opts and opts.override) then
    error("prompt: target already registered: " .. name)
  end

  if type(def) ~= "table" then
    error("prompt: invalid target definition for: " .. name)
  end

  if def.display_name ~= nil and type(def.display_name) ~= "string" then
    error("prompt: target '" .. name .. "' field 'display_name' must be a string")
  end

  local err = validate_triggers(name, def.triggers)
  if err then
    error("prompt: " .. err)
  end

  def.name = name
  def.display_name = def.display_name or name
  targets[name] = def

  return def
end

function M.unregister_target(name)
  targets[name] = nil
end

function M.get_target(name)
  return targets[name]
end

function M.has(name)
  return targets[name] ~= nil
end

function M.list_targets()
  local names = {}
  for name in pairs(targets) do
    table.insert(names, name)
  end
  table.sort(names)

  local list = {}
  for _, name in ipairs(names) do
    table.insert(list, targets[name])
  end
  return list
end

-- Union of every trigger character defined by a registered target, sorted.
-- Completion sources advertise this so the list always reflects the real
-- targets (including custom ones) instead of a hard-coded set.
function M.trigger_characters()
  local set = {}
  for _, def in pairs(targets) do
    for ch in pairs(def.triggers or {}) do
      set[ch] = true
    end
  end
  local list = {}
  for ch in pairs(set) do
    table.insert(list, ch)
  end
  table.sort(list)
  return list
end

return M
