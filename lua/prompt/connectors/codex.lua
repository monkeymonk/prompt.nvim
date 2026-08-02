local factory = require("prompt.connectors.factory")

return factory.make({
  name = "codex",
  meta = {
    name = "codex",
    stability = "stable",
    executable = "codex",
    version_command = { "codex", "--version" },
    tested_versions = nil,
  },
  available = function()
    return vim.fn.executable("codex") == 1
  end,
  roots = function(kind, ctx)
    local subdir = ({ skills = "skills", commands = "prompts" })[kind]
    if not subdir then
      return {}
    end
    return {
      {
        path = ctx.root .. "/.codex/" .. subdir,
        scope = "project",
        source_name = "codex_" .. kind,
        scanner = kind == "skills" and "skills" or "md_commands",
      },
      {
        path = vim.fn.expand("~/.codex") .. "/" .. subdir,
        scope = "user",
        source_name = "codex_" .. kind,
        scanner = kind == "skills" and "skills" or "md_commands",
      },
    }
  end,
})
