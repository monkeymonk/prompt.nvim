local M = {}

function M.make(connector_name, kind)
  return {
    name = connector_name .. "_" .. kind,
    complete = function(ctx, callback)
      local c = require("prompt.connectors").get(connector_name)
      if not c then
        return callback({})
      end

      -- Guard fire-once: a `discover` that calls back and THEN throws (e.g.
      -- in cleanup code after the callback) must not fire `callback` twice.
      local fired = false
      local function done(items)
        if fired then
          return
        end
        fired = true
        -- C5: run every connector's output through central validation before
        -- it reaches completion.
        callback(require("prompt.connectors.util").normalize_items(items or {}))
      end

      local ok, err = pcall(c.discover, kind, ctx, done)
      if not ok then
        require("prompt.log").debug(
          string.format("connector %s (%s) discover error: %s", connector_name, kind, tostring(err))
        )
        done({})
      end
    end,
  }
end

return M
