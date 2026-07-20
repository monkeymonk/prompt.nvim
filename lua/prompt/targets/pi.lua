return {
  name = "pi",
  display_name = "Pi",
  triggers = {
    ["/"] = { sources = { "pi_commands", "pi_skills", "pi_prompts" } },
    ["@"] = { sources = { "files", "directories" } },
  },
}
