local assert = assert

require("prompt").setup({})

local trigger = require("prompt.trigger")

local M = {}

function M.test_at_trigger_mid_line()
  local result = trigger.parse({ before_cursor = "prompt @src/au", target = "claude" })
  assert(result ~= nil, "expected a parse result")
  assert(result.trigger == "@", "expected trigger @, got " .. tostring(result.trigger))
  assert(result.query == "src/au", "expected query src/au, got " .. tostring(result.query))
  assert(result.start_col == 7, "expected start_col 7, got " .. tostring(result.start_col))
end

function M.test_at_trigger_rejected_mid_word()
  local result = trigger.parse({ before_cursor = "email@x.com", target = "claude" })
  assert(result == nil, "expected nil parse result")
end

function M.test_escaped_trigger()
  local result = trigger.parse({ before_cursor = "\\@", target = "claude" })
  assert(result == nil, "expected nil parse result for escaped trigger")
end

function M.test_slash_line_start_only()
  local result = trigger.parse({ before_cursor = "  /rev", target = "claude" })
  assert(result ~= nil, "expected a parse result")
  assert(result.trigger == "/", "expected trigger /, got " .. tostring(result.trigger))
  assert(result.query == "rev", "expected query rev, got " .. tostring(result.query))
end

function M.test_slash_rejected_not_line_start()
  local result = trigger.parse({ before_cursor = "1/2", target = "claude" })
  assert(result == nil, "expected nil parse result")
end

return M
