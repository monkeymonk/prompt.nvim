local factory = require("prompt.connectors.factory")

return factory.make({
  name = "opencode",
  meta = {
    name = "opencode", stability = "experimental", executable = "opencode",
    version_command = { "opencode", "--version" }, tested_versions = nil,
  },
  available = function() return vim.fn.executable("opencode") == 1 end,
  roots = function(kind, ctx)
    local subdir = ({ commands = "command", agents = "agent", skills = "skills" })[kind]
    if not subdir then return {} end
    return {
      { path = ctx.root .. "/.opencode/" .. subdir, scope = "project", source_name = "opencode_" .. kind, scanner = "md_" .. kind },
      { path = (vim.env.OPENCODE_CONFIG_DIR ~= nil and vim.env.OPENCODE_CONFIG_DIR ~= "" and vim.env.OPENCODE_CONFIG_DIR or vim.fn.expand("~/.config/opencode")) .. "/" .. subdir, scope = "user", source_name = "opencode_" .. kind, scanner = "md_" .. kind },
    }
  end,
})
