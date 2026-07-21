local M = {}

function M.test_shell_trigger_word_query()
  require("prompt").setup({})
  local T = require("prompt.trigger")

  local first = T.parse({ before_cursor = "!np", target = "claude" })
  assert(
    first and first.trigger == "!" and first.query == "np" and first.query_col == 1,
    "first word"
  )

  local arg = T.parse({ before_cursor = "! cat src/re", target = "claude" })
  assert(arg and arg.trigger == "!" and arg.query == "src/re", "argument word")

  -- The shell pre-check must not swallow ordinary line-start slash commands.
  local slash = T.parse({ before_cursor = "/rev", target = "claude" })
  assert(slash and slash.trigger == "/", "slash still parses")
end

function M.test_shell_path_completion()
  require("prompt").setup({})
  local fixture = vim.fn.tempname()
  vim.fn.mkdir(fixture .. "/lib", "p")
  vim.fn.writefile({ "x" }, fixture .. "/notes.md")

  local shell = require("prompt.sources.shell")
  local ctx = { cwd = fixture, root = fixture, before_cursor = "! cat no", query = "no" }
  local res
  shell.complete(ctx, function(r)
    res = r
  end)

  local found = false
  for _, c in ipairs(res or {}) do
    if c.insert_text == "notes.md" and c.source == "shell" then
      found = true
    end
  end
  assert(found, "! cat no should complete notes.md")
end

function M.test_shell_command_mode()
  require("prompt").setup({})
  local shell = require("prompt.sources.shell")
  local ctx = { cwd = vim.fn.getcwd(), before_cursor = "!", query = "" }
  local res
  shell.complete(ctx, function(r)
    res = r
  end)

  assert(type(res) == "table", "command mode returns a table")
  for _, c in ipairs(res) do
    assert(c.kind == "command", "command-mode items have kind command")
  end
end

return M
