local this_file = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(this_file, ":h:h")
vim.opt.runtimepath:prepend(root)
