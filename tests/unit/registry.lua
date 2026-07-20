local assert = assert

local registry = require("prompt.registry")

local M = {}

local NAME = "zzz_test_target"

function M.test_register_target_lifecycle()
  local def = registry.register_target(NAME, { triggers = {} })
  assert(type(def) == "table", "expected a table")

  local fetched = registry.get_target(NAME)
  assert(type(fetched) == "table", "expected a table")
  assert(fetched.name == NAME, "expected name " .. NAME .. ", got " .. tostring(fetched.name))

  local ok_dup = pcall(registry.register_target, NAME, { triggers = {} })
  assert(ok_dup == false, "expected registering a duplicate target to error")

  local ok_override = pcall(registry.register_target, NAME, { triggers = {} }, { override = true })
  assert(ok_override == true, "expected registering with override to succeed")

  local found = false
  for _, listed in ipairs(registry.list_targets()) do
    if listed.name == NAME then
      found = true
      break
    end
  end
  assert(found, "expected list_targets to contain " .. NAME)

  registry.unregister_target(NAME)
end

return M
