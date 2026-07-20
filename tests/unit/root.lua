local assert = assert

local root = require("prompt.root")

local M = {}

function M.test_detect_finds_git_marker_upward()
  root.clear()

  local base = vim.fn.tempname()
  vim.fn.mkdir(base, "p")
  vim.fn.mkdir(base .. "/.git", "p")
  vim.fn.mkdir(base .. "/sub/dir", "p")

  local detected = root.detect(base .. "/sub/dir")

  local norm_detected = (detected:gsub("/$", ""))
  local norm_base = (base:gsub("/$", ""))

  assert(norm_detected == norm_base, "expected " .. norm_base .. ", got " .. norm_detected)
end

return M
