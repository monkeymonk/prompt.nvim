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

return M
