local factory = require("prompt.connectors.factory")

return factory.make({
  name = "gemini",
  meta = {
    name = "gemini",
    stability = "experimental",
    executable = "gemini",
    version_command = { "gemini", "--version" },
    tested_versions = nil,
  },
  available = function()
    return vim.fn.executable("gemini") == 1
  end,
  roots = function(kind, ctx)
    if not ({ commands = true, skills = true, agents = true })[kind] then
      return {}
    end
    local scanner = kind == "commands" and "toml_commands"
      or (kind == "agents" and "md_agents" or "skills")
    return {
      {
        path = ctx.root .. "/.gemini/" .. kind,
        scope = "project",
        source_name = "gemini_" .. kind,
        scanner = scanner,
      },
      {
        path = vim.fn.expand("~/.gemini") .. "/" .. kind,
        scope = "user",
        source_name = "gemini_" .. kind,
        scanner = scanner,
      },
    }
  end,
})
