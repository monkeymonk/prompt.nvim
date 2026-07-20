local assert = assert

local M = {}

local function build_fixture()
  local fixture = vim.fn.tempname()
  vim.fn.mkdir(fixture, "p")
  vim.fn.mkdir(fixture .. "/.claude/skills/sec", "p")
  vim.fn.mkdir(fixture .. "/.claude/commands", "p")
  vim.fn.mkdir(fixture .. "/src", "p")

  vim.fn.writefile({ "# claude" }, fixture .. "/CLAUDE.md")
  vim.fn.writefile({ "---", "name: sec", "description: d", "---", "body" }, fixture .. "/.claude/skills/sec/SKILL.md")
  vim.fn.writefile({ "deploy the app" }, fixture .. "/.claude/commands/dep.md")
  vim.fn.writefile({ "return {}" }, fixture .. "/src/a.lua")

  return fixture
end

function M.test_at_trigger_completes_repo_file()
  require("prompt").setup({})
  local fixture = build_fixture()

  vim.cmd("enew")
  vim.b.prompt_target = "claude"
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "@src/a" })
  vim.wo.virtualedit = "onemore"
  vim.api.nvim_win_set_cursor(0, { 1, #"@src/a" })

  local ctx = require("prompt.context").build(0)

  local done = false
  local result = nil
  require("prompt.completion").complete(ctx, function(ranked)
    result = ranked
    done = true
  end)

  vim.wait(2000, function()
    return done
  end, 10)

  vim.wo.virtualedit = ""

  assert(done, "expected completion to finish")

  -- In segment mode (query contains "/"), the files source shows the bare
  -- basename as the label for readability while inserting the full path
  -- (see lua/prompt/sources/files.lua).
  local found = false
  for _, item in ipairs(result or {}) do
    if item.label == "a.lua" and item.insert_text == "src/a.lua" then
      found = true
      break
    end
  end
  assert(found, "expected a completion item with basename label a.lua and insert_text src/a.lua")
end

function M.test_slash_trigger_completes_commands_and_skills()
  require("prompt").setup({})
  local fixture = build_fixture()

  vim.cmd("enew")
  vim.b.prompt_target = "claude"
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "/" })
  vim.wo.virtualedit = "onemore"
  vim.api.nvim_win_set_cursor(0, { 1, 1 })

  local ctx = require("prompt.context").build(0)

  local done = false
  local result = nil
  require("prompt.completion").complete(ctx, function(ranked)
    result = ranked
    done = true
  end)

  vim.wait(2000, function()
    return done
  end, 10)

  vim.wo.virtualedit = ""

  assert(done, "expected completion to finish")

  local found_skill = false
  local found_command = false
  for _, item in ipairs(result or {}) do
    if item.label == "sec" then
      found_skill = true
    end
    if item.label == "dep" then
      found_command = true
    end
  end
  assert(found_skill, "expected a completion item with label sec")
  assert(found_command, "expected a completion item with label dep")
end

return M
