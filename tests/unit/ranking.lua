local assert = assert

local ranking = require("prompt.ranking")
local candidate = require("prompt.candidate")

local M = {}

local function build_candidates()
  local items = {
    { label = "src/authentication.lua" },
    { label = "src/config.lua" },
    { label = "src/database.lua" },
  }
  return candidate.normalize_all(items, {})
end

function M.test_prefix_basename_match_ranks_first()
  local normalized = build_candidates()
  local result = ranking.sort(normalized, { query = "au", _max_results = 10 })
  assert(#result > 0, "expected at least one result")
  assert(result[1].label:find("auth") ~= nil, "expected first result label to contain 'auth', got " .. tostring(result[1].label))
end

function M.test_no_match_returns_empty()
  local normalized = build_candidates()
  local result = ranking.sort(normalized, { query = "zzzzzqqqqq", _max_results = 10 })
  assert(#result == 0, "expected no results, got " .. #result)
end

return M
