local M = {}

local store = {}

local function now()
  return vim.uv.now()
end

function M.get(key)
  local entry = store[key]
  if entry == nil then
    return nil
  end

  if entry.expires and now() > entry.expires then
    store[key] = nil
    return nil
  end

  return entry.value
end

function M.set(key, value, ttl_ms)
  local cfg = require("prompt.config").get().cache
  if not cfg.enabled then
    return value
  end

  ttl_ms = ttl_ms or cfg.ttl_ms
  store[key] = { value = value, expires = ttl_ms and (now() + ttl_ms) or nil }
  return value
end

function M.invalidate(key)
  store[key] = nil
end

function M.invalidate_prefix(prefix)
  for k in pairs(store) do
    if type(k) == "string" and k:sub(1, #prefix) == prefix then
      store[k] = nil
    end
  end
end

function M.invalidate_project(root, prefix)
  for k in pairs(store) do
    if
      (prefix == nil or (type(k) == "string" and k:sub(1, #prefix) == prefix))
      and (root == nil or (type(k) == "string" and k:find(root, 1, true)))
    then
      store[k] = nil
    end
  end
end

function M.clear()
  store = {}
end

return M
