-- OpenCode connector. Honors OPENCODE_CONFIG_DIR; paths are version-tentative.
local M = {}

M.name = "opencode"

-- #20/#21: compatibility metadata used by `:checkhealth prompt`.
-- `tested_versions` is left nil (no verified range recorded yet); health
-- reports this as an untested range rather than inventing numbers.
M.meta = {
  name = "opencode",
  stability = "experimental",
  executable = "opencode",
  version_command = { "opencode", "--version" },
  tested_versions = nil,
}

function M.available()
  return vim.fn.executable("opencode") == 1
end

local function user_base()
  local dir = vim.env.OPENCODE_CONFIG_DIR
  if dir ~= nil and dir ~= "" then
    return dir
  end
  return vim.fn.expand("~/.config/opencode")
end

function M.discover(kind, ctx, callback)
  local key = ("conn:opencode:%s:%s"):format(kind, ctx.root or "")
  local cached = require("prompt.cache").get(key)
  if cached then
    return callback(cached)
  end

  local util = require("prompt.connectors.util")
  local project = ctx.root .. "/.opencode"
  local user = user_base()

  local out = {}
  if kind == "commands" then
    util.scan_md_commands(project .. "/command", "project", "opencode_commands", out)
    util.scan_md_commands(user .. "/command", "user", "opencode_commands", out)
  elseif kind == "agents" then
    util.scan_agents(project .. "/agent", "project", "opencode_agents", out)
    util.scan_agents(user .. "/agent", "user", "opencode_agents", out)
  elseif kind == "skills" then
    util.scan_skills(project .. "/skills", "project", "opencode_skills", out)
    util.scan_skills(user .. "/skills", "user", "opencode_skills", out)
  end

  require("prompt.cache").set(key, out)
  callback(out)
end

function M.invalidate(root)
  require("prompt.cache").invalidate_project(root)
end

return M
