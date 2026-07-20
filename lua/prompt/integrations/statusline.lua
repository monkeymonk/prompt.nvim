local M = {}

function M.target(bufnr)
  bufnr = bufnr or 0
  local t = require("prompt.target").resolve(bufnr)
  if not t then
    return ""
  end
  local def = require("prompt.registry").get_target(t)
  return "Prompt: " .. ((def and def.display_name) or t)
end

function M.status(bufnr)
  bufnr = bufnr or 0
  if not require("prompt.buffer").is_attached(bufnr) then
    return ""
  end
  local base = M.target(bufnr)
  local extra = require("prompt.bridge").is_bridge_buffer(bufnr) and " · bridge" or ""
  return base:gsub("^Prompt: ", "Prompt · ") .. extra
end

return M
