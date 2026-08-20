local assert = assert

local redact = require("prompt.redact")

local M = {}

local function scan_one(line)
  local lines, count = redact.scan({ line })
  return lines[1], count
end

function M.test_no_match_is_untouched()
  local out, count = scan_one("just a normal sentence about tokenizers and authors")
  assert(count == 0, "expected 0 matches, got " .. count)
  assert(out == "just a normal sentence about tokenizers and authors", "line must be unchanged")
end

function M.test_aws_access_key()
  local out, count = scan_one("aws_key = AKIAABCDEFGHIJKLMNOP")
  assert(count == 1, "expected 1 match, got " .. count)
  assert(out:find("AKIA", 1, true) == nil, "AWS key must be masked: " .. out)
  assert(out:find("[REDACTED]", 1, true), "expected mask marker: " .. out)
end

function M.test_github_token()
  local out, count = scan_one("GITHUB_TOKEN=ghp_" .. string.rep("a", 36))
  assert(count >= 1, "expected at least 1 match, got " .. count)
  assert(out:find("ghp_", 1, true) == nil, "GitHub token must be masked: " .. out)
end

function M.test_jwt()
  local jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
  local out, count = scan_one("Authorization header: " .. jwt)
  assert(count == 1, "expected 1 match, got " .. count)
  assert(out:find(jwt, 1, true) == nil, "JWT must be masked: " .. out)
end

function M.test_generic_secret_assignment()
  local out, count = scan_one('password: "hunter2"')
  assert(count == 1, "expected 1 match, got " .. count)
  assert(out == 'password: "[REDACTED]"', "got: " .. out)
end

function M.test_snake_case_key_is_matched()
  local out, count = scan_one("STRIPE_SECRET_KEY=sk_test_should_not_leak_either")
  -- both the assignment hint and the sk_-shaped value could fire; either way
  -- the raw value must not survive.
  assert(count >= 1, "expected at least 1 match, got " .. count)
  assert(out:find("should_not_leak_either", 1, true) == nil, "value must be masked: " .. out)
end

function M.test_key_name_alone_is_not_a_false_positive()
  local out, count = scan_one("primary_key = 42")
  assert(count == 0, "primary_key is not a secret, got " .. count .. ": " .. out)
end

function M.test_word_boundary_avoids_tokenizer_false_positive()
  local out, count = scan_one("tokenizer = AutoTokenizer.from_pretrained(name)")
  assert(count == 0, "tokenizer assignment must not be flagged, got " .. count .. ": " .. out)
end

function M.test_pem_private_key_block_is_collapsed()
  local lines = {
    "before",
    "-----BEGIN RSA PRIVATE KEY-----",
    "MIIEpAIBAAKCAQEAsecretmaterial",
    "moresecretmaterial==",
    "-----END RSA PRIVATE KEY-----",
    "after",
  }
  local out, count = redact.scan(lines)
  assert(count == 1, "expected 1 match, got " .. count)
  assert(out[1] == "before")
  assert(out[2] == "-----BEGIN RSA PRIVATE KEY-----")
  assert(out[3] == "[REDACTED] PRIVATE KEY BODY", "got: " .. tostring(out[3]))
  assert(out[4] == "-----END RSA PRIVATE KEY-----", "got: " .. tostring(out[4]))
  assert(out[5] == "after", "got: " .. tostring(out[5]))
  assert(#out == 5, "expected 5 output lines, got " .. #out)
end

function M.test_scan_returns_new_table()
  local input = { "unchanged line" }
  local out = redact.scan(input)
  assert(out ~= input, "scan must not return the same table instance")
  assert(out[1] == input[1])
end

function M.test_apply_range_only_touches_the_given_lines()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "sk-" .. string.rep("a", 30),
    "sk-" .. string.rep("b", 30),
    "sk-" .. string.rep("c", 30),
  })

  local count = redact.apply_range(buf, 2, 2)
  assert(count == 1, "expected 1 match, got " .. count)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(lines[1]:find("aaa", 1, true), "line 1 outside the range must survive: " .. lines[1])
  assert(lines[2] == "[REDACTED]", "line 2 inside the range must be redacted: " .. lines[2])
  assert(lines[3]:find("ccc", 1, true), "line 3 outside the range must survive: " .. lines[3])

  vim.api.nvim_buf_delete(buf, { force = true })
end

function M.test_apply_covers_the_whole_buffer_by_default()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "before", "password: \"hunter2\"", "after" })

  local count = redact.apply(buf)
  assert(count == 1, "expected 1 match, got " .. count)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(lines[2] == 'password: "[REDACTED]"', "got: " .. lines[2])

  vim.api.nvim_buf_delete(buf, { force = true })
end

function M.test_apply_range_is_a_noop_when_nothing_matches()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "nothing to see here" })

  local count = redact.apply_range(buf, 1, 1)
  assert(count == 0, "expected 0 matches, got " .. count)

  vim.api.nvim_buf_delete(buf, { force = true })
end

return M
