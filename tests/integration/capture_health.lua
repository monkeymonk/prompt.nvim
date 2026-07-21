-- Helper for install_smoke_spec.sh: runs `:checkhealth prompt` and writes the
-- resulting report buffer's lines to $PROMPT_NVIM_TEST_HEALTH_OUT, one line
-- per line of the report. Expects to be launched with
-- `-u tests/minimal_init.lua` (which already puts the plugin on runtimepath).
require("prompt").setup({})
vim.cmd("checkhealth prompt")
vim.wait(2000)

local target
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[bufnr].filetype == "checkhealth" then
    target = bufnr
  end
end

local out = vim.env.PROMPT_NVIM_TEST_HEALTH_OUT
if target and out and out ~= "" then
  vim.fn.writefile(vim.api.nvim_buf_get_lines(target, 0, -1, false), out)
end

vim.cmd("qa!")
