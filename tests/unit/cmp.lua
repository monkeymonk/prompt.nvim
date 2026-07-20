local M = {}

function M.test_cmp_source_builds_items()
  require("prompt").setup({})
  local fixture = vim.fn.tempname()
  vim.fn.mkdir(fixture .. "/src", "p")
  vim.fn.writefile({ "-- claude" }, fixture .. "/CLAUDE.md")
  vim.fn.writefile({ "return {}" }, fixture .. "/src/a.lua")

  vim.cmd("enew")
  require("prompt.buffer").attach(0, "claude")
  vim.cmd("cd " .. vim.fn.fnameescape(fixture))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "@src/a" })
  vim.wo.virtualedit = "onemore"
  vim.api.nvim_win_set_cursor(0, { 1, #"@src/a" })

  local src = require("prompt.integrations.cmp").new()
  assert(src:is_available() == true, "available in attached buffer")
  assert(vim.tbl_contains(src:get_trigger_characters(), "!"), "trigger chars include !")

  local done, payload = false, nil
  src:complete({}, function(p)
    payload = p
    done = true
  end)
  vim.wait(2000, function()
    return done
  end)
  vim.wo.virtualedit = ""

  assert(payload and payload.items and #payload.items > 0, "returned items")
  local item = payload.items[1]
  assert(item.textEdit and item.textEdit.range, "item has an LSP textEdit")
  assert(item.insertText, "item has insertText")
  assert(type(item.kind) == "number", "kind is a numeric LSP kind")
end

function M.test_cmp_source_unavailable_when_detached()
  require("prompt").setup({})
  vim.cmd("enew")
  local src = require("prompt.integrations.cmp").new()
  assert(src:is_available() == false, "not available in a plain buffer")
end

return M
