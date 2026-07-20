return {
  name = "opencode",
  display_name = "OpenCode",
  triggers = {
    ["@"] = { sources = { "files", "directories", "opencode_agents" } },
    ["/"] = { sources = { "opencode_commands" }, line_start_only = true },
  },
}
