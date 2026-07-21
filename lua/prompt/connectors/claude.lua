local M = {}

M.name = "claude"

-- #20/#21: compatibility metadata used by `:checkhealth prompt`.
-- `tested_versions` is left nil (no verified range recorded yet); health
-- reports this as an untested range rather than inventing numbers.
M.meta = {
  name = "claude",
  stability = "stable",
  executable = "claude",
  version_command = { "claude", "--version" },
  tested_versions = nil,
}

function M.available()
  return vim.fn.executable("claude") == 1
end

local function user_base()
  return vim.fn.expand("~/.claude")
end

function M.discover(kind, ctx, callback)
  local key = ("conn:claude:%s:%s"):format(kind, ctx.root or "")
  local cached = require("prompt.cache").get(key)
  if cached then
    return callback(cached)
  end

  local util = require("prompt.connectors.util")
  local project = ctx.root .. "/.claude"
  local user = user_base()
  local out = {}

  if kind == "commands" then
    util.scan_md_commands(project .. "/commands", "project", "claude_commands", out)
    util.scan_md_commands(user .. "/commands", "user", "claude_commands", out)
  elseif kind == "skills" then
    util.scan_skills(project .. "/skills", "project", "claude_skills", out)
    util.scan_skills(user .. "/skills", "user", "claude_skills", out)
  elseif kind == "agents" then
    util.scan_agents(project .. "/agents", "project", "claude_agents", out)
    util.scan_agents(user .. "/agents", "user", "claude_agents", out)
  end

  require("prompt.cache").set(key, out)
  callback(out)
end

function M.invalidate(root)
  require("prompt.cache").invalidate_project(root)
end

return M
