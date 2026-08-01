local factory = require("prompt.connectors.factory")

local function user_base()
  return vim.fn.expand("~/.claude")
end

return factory.make({
  name = "claude",
  meta = {
    name = "claude", stability = "stable", executable = "claude",
    version_command = { "claude", "--version" }, tested_versions = nil,
  },
  available = function()
    return vim.fn.executable("claude") == 1
  end,
  roots = function(kind, ctx)
    local project = ctx.root .. "/.claude"
    local user = user_base()
    local scanner = ({ commands = "md_commands", skills = "skills", agents = "md_agents" })[kind]
    if not scanner then return {} end
    return {
      { path = project .. "/" .. (kind == "commands" and "commands" or kind), scope = "project", source_name = "claude_" .. kind, scanner = scanner },
      { path = user .. "/" .. (kind == "commands" and "commands" or kind), scope = "user", source_name = "claude_" .. kind, scanner = scanner },
    }
  end,
})
