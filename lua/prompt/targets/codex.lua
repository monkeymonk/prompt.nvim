return {
  name = "codex",
  display_name = "Codex CLI",
  -- Codex CLI now shares Claude Code's composer bindings: @ files, / commands
  -- and skills (line start), and ! shell mode.
  triggers = {
    ["@"] = { sources = { "files", "directories" } },
    ["/"] = { sources = { "codex_commands", "codex_skills" }, line_start_only = true },
    ["!"] = { sources = { "shell" }, line_start_only = true, word_query = true },
  },
}
