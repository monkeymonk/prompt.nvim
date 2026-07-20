local M = {}
M.name = "files"

function M.complete(ctx, callback)
  require("prompt.sources.pathsource").complete(ctx, callback, {
    entry_type = "file",
    kind = "file",
    source = "files",
    repo_field = "files",
  })
end

return M
