local assert = assert

local filesystem = require("prompt.connectors.filesystem")

local M = {}

local ROOT = "/tmp/prompt-nvim-test-root"

function M.test_bare_query_is_repo_mode()
  local spec = filesystem.resolve_query(ROOT, "ses")
  assert(spec.mode == "repo", "expected mode repo, got " .. tostring(spec.mode))
end

function M.test_relative_segment_query()
  local spec = filesystem.resolve_query(ROOT, "src/")
  assert(spec.mode == "segment", "expected mode segment, got " .. tostring(spec.mode))
  assert(spec.dir == ROOT .. "/src", "expected dir " .. ROOT .. "/src, got " .. tostring(spec.dir))
  assert(spec.prefix == "src/", "expected prefix src/, got " .. tostring(spec.prefix))
  assert(spec.base == "", "expected empty base, got " .. tostring(spec.base))
end

function M.test_parent_segment_query()
  local spec = filesystem.resolve_query(ROOT, "../")
  assert(spec.mode == "segment", "expected mode segment, got " .. tostring(spec.mode))
  assert(
    spec.dir == vim.fn.fnamemodify(ROOT, ":h"),
    "expected parent dir, got " .. tostring(spec.dir)
  )
end

function M.test_absolute_segment_query()
  local spec = filesystem.resolve_query(ROOT, "/tmp/")
  assert(spec.mode == "segment", "expected mode segment, got " .. tostring(spec.mode))
  assert(spec.dir == "/tmp", "expected dir /tmp, got " .. tostring(spec.dir))
end

function M.test_home_segment_query()
  local spec = filesystem.resolve_query(ROOT, "~/")
  assert(spec.mode == "segment", "expected mode segment, got " .. tostring(spec.mode))
  local expected = (vim.fn.expand("~"):gsub("/$", ""))
  local got = (spec.dir:gsub("/$", ""))
  assert(got == expected, "expected dir " .. expected .. ", got " .. got)
end

return M
