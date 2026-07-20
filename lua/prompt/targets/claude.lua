return {
  name = "claude",
  display_name = "Claude Code",
  triggers = {
    ["@"] = { sources = { "files", "directories" } },
    ["/"] = { sources = { "claude_commands", "claude_skills" }, line_start_only = true },
    ["!"] = { sources = { "shell" }, line_start_only = true, word_query = true },
  },
}
