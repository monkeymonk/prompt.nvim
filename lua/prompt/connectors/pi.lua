local factory = require("prompt.connectors.factory")

return factory.make({
  name = "pi",
  meta = {
    name = "pi", stability = "experimental", executable = "pi",
    version_command = { "pi", "--version" }, tested_versions = nil,
  },
  available = function() return vim.fn.executable("pi") == 1 end,
  roots = function(kind, ctx)
    if not ({ commands = true, skills = true, prompts = true })[kind] then return {} end
    local users = { vim.fn.expand("~/.config/pi"), vim.fn.expand("~/.pi") }
    local roots = { { path = ctx.root .. "/.pi/" .. kind, scope = "project", source_name = "pi_" .. kind, scanner = "md_" .. kind } }
    for _, base in ipairs(users) do
      roots[#roots + 1] = { path = base .. "/" .. kind, scope = "user", source_name = "pi_" .. kind, scanner = "md_" .. kind }
    end
    return roots
  end,
})
