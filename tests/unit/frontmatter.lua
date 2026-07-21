local assert = assert

local frontmatter = require("prompt.frontmatter")

local M = {}

function M.test_parse_lines_with_frontmatter()
  local result =
    frontmatter.parse_lines({ "---", 'name: "sec"', "description: unquoted value", "---" })
  assert(result.name == "sec", "expected name sec, got " .. tostring(result.name))
  assert(
    result.description == "unquoted value",
    "expected description unquoted value, got " .. tostring(result.description)
  )
end

function M.test_parse_lines_without_frontmatter()
  local result = frontmatter.parse_lines({ "no frontmatter here", "just text" })
  assert(next(result) == nil, "expected an empty table")
end

return M
