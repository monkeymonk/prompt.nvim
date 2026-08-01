local assert = assert

local cache = require("prompt.cache")

local M = {}

function M.test_set_get_invalidate_clear()
  cache.set("t:k1", "v1")
  assert(cache.get("t:k1") == "v1", "expected v1")

  cache.invalidate("t:k1")
  assert(cache.get("t:k1") == nil, "expected nil after invalidate")

  cache.set("t:k2", "v2")
  assert(cache.get("t:k2") == "v2", "expected v2")

  cache.clear()
  assert(cache.get("t:k2") == nil, "expected nil after clear")
end

function M.test_prefix_invalidation_is_scoped()
  local cache = require("prompt.cache")
  cache.clear()
  cache.set("conn:claude:skills", { "connector" })
  cache.set("fs:/project", { "filesystem" })
  cache.set("shell:commands", { "shell" })

  cache.invalidate_prefix("conn:")

  assert(cache.get("conn:claude:skills") == nil, "connector entries must be removed")
  assert(cache.get("fs:/project")[1] == "filesystem", "filesystem entries must survive")
  assert(cache.get("shell:commands")[1] == "shell", "shell entries must survive")

  cache.clear()
  cache.set("conn:claude:skills", { "connector" })
  cache.set("fs:/project", { "filesystem" })
  cache.clear()
  assert(cache.get("conn:claude:skills") == nil, "full refresh must remove connector entries")
  assert(cache.get("fs:/project") == nil, "full refresh must remove filesystem entries")
end

return M
