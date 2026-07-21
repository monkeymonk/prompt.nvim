-- Pi connector. Paths are best-effort/unverified (pi not installed on dev machine).
local M = {}

M.name = "pi"

-- #20/#21: compatibility metadata used by `:checkhealth prompt`.
-- `tested_versions` is left nil (no verified range recorded yet); health
-- reports this as an untested range rather than inventing numbers.
M.meta = {
  name = "pi",
  stability = "experimental",
  executable = "pi",
  version_command = { "pi", "--version" },
  tested_versions = nil,
}

function M.available()
  return vim.fn.executable("pi") == 1
end

local function user_bases()
  return { vim.fn.expand("~/.config/pi"), vim.fn.expand("~/.pi") }
end

function M.discover(kind, ctx, callback)
  local key = ("conn:pi:%s:%s"):format(kind, ctx.root or "")
  local cached = require("prompt.cache").get(key)
  if cached then
    return callback(cached)
  end

  local util = require("prompt.connectors.util")
  local project = ctx.root .. "/.pi"
  local users = user_bases()

  local out = {}
  if kind == "commands" then
    util.scan_md_commands(project .. "/commands", "project", "pi_commands", out)
    for _, base in ipairs(users) do
      util.scan_md_commands(base .. "/commands", "user", "pi_commands", out)
    end
  elseif kind == "skills" then
    util.scan_skills(project .. "/skills", "project", "pi_skills", out)
    for _, base in ipairs(users) do
      util.scan_skills(base .. "/skills", "user", "pi_skills", out)
    end
  elseif kind == "prompts" then
    util.scan_md_prompts(project .. "/prompts", "project", "pi_prompts", out)
    for _, base in ipairs(users) do
      util.scan_md_prompts(base .. "/prompts", "user", "pi_prompts", out)
    end
  end

  require("prompt.cache").set(key, out)
  callback(out)
end

function M.invalidate(root)
  require("prompt.cache").invalidate_project(root)
end

return M
