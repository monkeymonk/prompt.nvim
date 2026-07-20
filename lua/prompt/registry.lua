local M = {}

local targets = {}

M.NAME_PATTERN = "^[a-z0-9_-]+$"

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
