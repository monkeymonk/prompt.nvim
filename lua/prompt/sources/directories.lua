local M = {}
M.name = "directories"

function M.complete(ctx, callback)
  local trailing = require("prompt.config").get().paths.directory_trailing_slash
  require("prompt.sources.pathsource").complete(ctx, callback, {
    entry_type = "directory",
    kind = "directory",
    source = "directories",
    repo_field = "directories",
    decorate = function(s)
      return trailing and (s .. "/") or s
    end,
  })
end

return M
