-- Codex CLI connector. Paths are version-tentative (Codex ~/.codex/{skills,prompts}); verify per release.
local M = {}

M.name = "codex"

-- #20/#21: compatibility metadata used by `:checkhealth prompt`.
-- `tested_versions` is left nil (no verified range recorded yet); health
-- reports this as an untested range rather than inventing numbers.
M.meta = {
  name = "codex",
  stability = "stable",
  executable = "codex",
  version_command = { "codex", "--version" },
  tested_versions = nil,
}

function M.available()
  return vim.fn.executable("codex") == 1
end

local function user_base()
  return vim.fn.expand("~/.codex")
end

function M.discover(kind, ctx, callback)
  local key = ("conn:codex:%s:%s"):format(kind, ctx.root or "")
  local cached = require("prompt.cache").get(key)
  if cached then
    return callback(cached)
  end

  local util = require("prompt.connectors.util")
  local project = ctx.root .. "/.codex"
  local user = user_base()

  local out = {}
  if kind == "skills" then
    util.scan_skills(project .. "/skills", "project", "codex_skills", out)
    util.scan_skills(user .. "/skills", "user", "codex_skills", out)
  elseif kind == "commands" then
    util.scan_md_commands(project .. "/prompts", "project", "codex_commands", out)
    util.scan_md_commands(user .. "/prompts", "user", "codex_commands", out)
  end

  require("prompt.cache").set(key, out)
  callback(out)
end

function M.invalidate(root)
  require("prompt.cache").invalidate_project(root)
end

return M
