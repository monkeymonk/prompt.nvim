local M = {}

function M.resolve(bufnr)
  bufnr = bufnr or 0
  local registry = require("prompt.registry")

  local b = vim.b[bufnr].prompt_target
  if b and registry.has(b) then
    return b
  end

  local env = vim.env.PROMPT_NVIM_TARGET
  if env and env ~= "" and registry.has(env) then
    return env
  end

  local d = require("prompt.config").get().default_target
  if d and registry.has(d) then
    return d
  end

  return nil
end

return M
