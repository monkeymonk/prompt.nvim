local M = {}
M.name = "files"

function M.complete(ctx, callback)
  return require("prompt.sources.pathsource").complete(ctx, callback, {
    entry_type = "file",
    kind = "file",
    source = "files",
    repo_field = "files",
  })
end

return M
