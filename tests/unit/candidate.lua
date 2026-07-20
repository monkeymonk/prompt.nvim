local assert = assert

local candidate = require("prompt.candidate")

local M = {}

function M.test_normalize_from_label()
  local result = candidate.normalize({ label = "Foo" }, {})
  assert(result.insert_text == "Foo", "expected insert_text Foo")
  assert(result.kind == "file", "expected kind file")
  assert(result.filter_text == "Foo", "expected filter_text Foo")
  assert(result.sort_text == "Foo", "expected sort_text Foo")
end

function M.test_normalize_from_insert_text()
  local result = candidate.normalize({ insert_text = "bar" }, {})
  assert(result.label == "bar", "expected label bar")
  assert(result.kind == "file", "expected kind file")
end

function M.test_normalize_preserves_explicit_kind()
  local result = candidate.normalize({ label = "x", kind = "skill" }, {})
  assert(result.kind == "skill", "expected kind skill")
end

return M
