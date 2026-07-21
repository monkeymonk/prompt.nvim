-- Isolated Neovim config used only to record ../assets/demo.gif (see README.md
-- in this directory). It resolves the plugin repo root from this file's own
-- location, so it works from any checkout without hard-coded paths.
local here = debug.getinfo(1, "S").source:sub(2)
local repo = vim.fn.fnamemodify(here, ":p:h:h") -- demo/init.lua -> repo root
vim.opt.runtimepath:prepend(repo)

vim.o.termguicolors = true
vim.o.number = false
vim.o.signcolumn = "no"
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.showcmd = false
vim.o.showmode = false
vim.o.completeopt = "menu,menuone,noselect"
vim.o.timeoutlen = 3000
vim.o.pumheight = 8
pcall(vim.cmd.colorscheme, "habamax")

-- <Tab> triggers the built-in (framework-free) completer so the demo needs no
-- blink.cmp / nvim-cmp.
require("prompt").setup({ keymaps = { complete = "<Tab>" } })
