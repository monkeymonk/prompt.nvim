-- Gemini CLI connector. Paths are version-tentative; verify per release.
local M = {}

M.name = "gemini"

-- #20/#21: compatibility metadata used by `:checkhealth prompt`.
-- `tested_versions` is left nil (no verified range recorded yet); health
-- reports this as an untested range rather than inventing numbers.
M.meta = {
  name = "gemini",
  stability = "experimental",
  executable = "gemini",
  version_command = { "gemini", "--version" },
  tested_versions = nil,
}

function M.available()
  return vim.fn.executable("gemini") == 1
end

local function user_base()
  return vim.fn.expand("~/.gemini")
end

function M.discover(kind, ctx, callback)
  local key = ("conn:gemini:%s:%s"):format(kind, ctx.root or "")
  local cached = require("prompt.cache").get(key)
  if cached then
    return callback(cached)
  end

  local util = require("prompt.connectors.util")
  local project = ctx.root .. "/.gemini"
  local user = user_base()

  local out = {}
  if kind == "commands" then
    util.scan_toml_commands(project .. "/commands", "project", "gemini_commands", out)
    util.scan_toml_commands(user .. "/commands", "user", "gemini_commands", out)
  elseif kind == "skills" then
    util.scan_skills(project .. "/skills", "project", "gemini_skills", out)
    util.scan_skills(user .. "/skills", "user", "gemini_skills", out)
  elseif kind == "agents" then
    util.scan_agents(project .. "/agents", "project", "gemini_agents", out)
    util.scan_agents(user .. "/agents", "user", "gemini_agents", out)
  end

  require("prompt.cache").set(key, out)
  callback(out)
end

function M.invalidate(root)
  require("prompt.cache").invalidate_project(root)
end

return M
