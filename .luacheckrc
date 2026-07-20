std = "lua51"
max_line_length = 120

globals = {
  "vim",
}

read_globals = {
  "vim",
}

-- Neovim plugin: allow common patterns.
ignore = {
  "212", -- unused argument
  "631", -- line too long (handled by max_line_length)
}
