std = "lua51"
max_line_length = 120

-- `vim` is a writable global here: the plugin assigns buffer/window-local
-- options and vars through it (vim.b/bo/wo.* = ...). Listing it under
-- read_globals would flag every such assignment as "setting a read-only field".
globals = {
  "vim",
}

-- Neovim plugin: allow common patterns.
ignore = {
  "212", -- unused argument
  "631", -- line too long (handled by max_line_length)
}
