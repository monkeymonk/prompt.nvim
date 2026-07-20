local M = {}

M.groups = {
  file = "PromptReferenceFile",
  directory = "PromptReferenceDirectory",
  skill = "PromptReferenceSkill",
  command = "PromptReferenceCommand",
  agent = "PromptReferenceAgent",
  target = "PromptTarget",
  deprecated = "PromptDeprecated",
}

M.trigger_group = { ["@"] = "file", ["/"] = "command", ["$"] = "skill", ["!"] = "command" }

local ns = vim.api.nvim_create_namespace("prompt_highlight")

function M.setup_hl()
  vim.api.nvim_set_hl(0, M.groups.file, { link = "Underlined", default = true })
  vim.api.nvim_set_hl(0, M.groups.directory, { link = "Directory", default = true })
  vim.api.nvim_set_hl(0, M.groups.skill, { link = "Special", default = true })
  vim.api.nvim_set_hl(0, M.groups.command, { link = "Function", default = true })
  vim.api.nvim_set_hl(0, M.groups.agent, { link = "Identifier", default = true })
  vim.api.nvim_set_hl(0, M.groups.target, { link = "Title", default = true })
  vim.api.nvim_set_hl(0, M.groups.deprecated, { link = "Comment", default = true })
end

function M.apply(bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local config = require("prompt.config").get()
  if not config.highlight.enabled then return end
  if not require("prompt.buffer").is_attached(bufnr) then return end

  local target_name = require("prompt.target").resolve(bufnr)
  if not target_name then return end
  local def = require("prompt.registry").get_target(target_name)
  if not def or not def.triggers then return end

  pcall(function()
    local trigger = require("prompt.trigger")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for row, line in ipairs(lines) do
      for _, occ in ipairs(trigger.scan_line(line, def.triggers)) do
        local group = M.groups[M.trigger_group[occ.ch] or "file"]
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row - 1, occ.col_start, {
          end_col = occ.col_end,
          hl_group = group,
        })
      end
    end
  end)
end

function M.attach(bufnr)
  bufnr = bufnr or 0
  local config = require("prompt.config").get()
  if not config.highlight.enabled then return end

  local group_name = ("prompt_hl_%d"):format(bufnr)
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      M.apply(bufnr)
    end,
  })
  M.apply(bufnr)
end

function M.detach(bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  pcall(vim.api.nvim_del_augroup_by_name, ("prompt_hl_%d"):format(bufnr))
end

return M
