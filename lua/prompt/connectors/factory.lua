local M = {}

local function encode(value)
  return (value:gsub("%%", "%%25"):gsub(":", "%%3A"))
end

local function roots_for(def, kind, ctx)
  local roots = def.roots(kind, ctx) or {}
  local paths = {}
  for _, root in ipairs(roots) do
    paths[#paths + 1] = root.path
  end
  return roots, paths
end

function M.make(def)
  local connector = {
    name = def.name,
    meta = def.meta,
    available = def.available,
  }

  function connector.discover(kind, ctx, callback)
    local roots, paths = roots_for(def, kind, ctx)
    local key_parts = { "conn", encode(def.name), encode(kind), encode(ctx.root or "") }
    for _, path in ipairs(paths) do
      key_parts[#key_parts + 1] = encode(path)
    end
    local key = table.concat(key_parts, ":")
    local cache = require("prompt.cache")
    local cached = cache.get(key)
    if cached then
      callback(cached)
      return function() end
    end

    local fired = false
    local cancelled = false
    local function done(items)
      if fired then
        return
      end
      fired = true
      if not cancelled then
        cache.set(key, items)
      end
      callback(items)
    end

    local cancel = require("prompt.connectors.util").scan_async(roots, function(items)
      done(items)
    end)
    return function()
      if cancelled then
        return
      end
      cancelled = true
      cancel()
    end
  end

  function connector.invalidate(root)
    if root == nil then
      require("prompt.cache").invalidate_prefix("conn:")
    else
      require("prompt.cache").invalidate_project(root, "conn:")
    end
  end

  return connector
end

return M
