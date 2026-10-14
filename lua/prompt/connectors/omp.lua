local factory = require("prompt.connectors.factory")

local function user_base()
  return vim.fn.expand("~/.omp/agent")
end

return factory.make({
  name = "omp",
  meta = {
    name = "omp",
    stability = "experimental",
    executable = "omp",
    version_command = { "omp", "--version" },
    tested_versions = nil,
  },
  available = function()
    return vim.fn.executable("omp") == 1
  end,
  roots = function(kind, ctx)
    local scanner = ({ commands = "md_commands", skills = "skills", prompts = "md_prompts" })[kind]
    if not scanner then
      return {}
    end
    return {
      {
        path = ctx.root .. "/.omp/" .. kind,
        scope = "project",
        source_name = "omp_" .. kind,
        scanner = scanner,
      },
      {
        path = user_base() .. "/" .. kind,
        scope = "user",
        source_name = "omp_" .. kind,
        scanner = scanner,
      },
    }
  end,
})
