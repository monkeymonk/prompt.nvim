return {
  name = "gemini",
  display_name = "Gemini CLI",
  triggers = {
    ["@"] = { sources = { "files", "directories" } },
    ["/"] = { sources = { "gemini_commands", "gemini_skills", "gemini_agents" }, line_start_only = true },
  },
}
