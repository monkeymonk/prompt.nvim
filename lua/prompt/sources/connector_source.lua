local M = {}

function M.make(connector_name, kind)
  return {
    name = connector_name .. "_" .. kind,
    complete = function(ctx, callback)
      local c = require("prompt.connectors").get(connector_name)
      if not c then
        return callback({})
      end
      local ok = pcall(c.discover, kind, ctx, function(items)
        callback(items or {})
      end)
      if not ok then
        callback({})
      end
    end,
  }
end

return M
