local M = {}

local cache = {}

function M.detect(start)
  start = start or vim.fn.getcwd()

  if cache[start] then
    return cache[start]
  end

  local markers = require("prompt.config").get().paths.root_markers
  local found = vim.fs.find(markers, { path = start, upward = true })[1]
  local root = found and vim.fn.fnamemodify(found, ":h") or start

  cache[start] = root
  return root
end

function M.clear()
  cache = {}
end

return M
