local M = {}

function M.check()
  vim.health.start("prompt.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10+")
  else
    vim.health.error("Neovim 0.10+ required")
  end

  if vim.fn.executable("prompt-nvim") == 1 then
    vim.health.ok("prompt-nvim executable found")
  else
    vim.health.warn("prompt-nvim executable not found on PATH", { "Install bin/prompt-nvim into your PATH" })
  end

  local has_so = #vim.api.nvim_get_runtime_file("parser/markdown.so", true) > 0
  local has_dll = #vim.api.nvim_get_runtime_file("parser/markdown.dll", true) > 0
  if has_so or has_dll then
    vim.health.ok("markdown Treesitter parser found")
  else
    vim.health.warn("markdown Treesitter parser not found")
  end

  vim.health.start("Targets")
  local targets = require("prompt.registry").list_targets()
  if #targets == 0 then
    vim.health.warn("No targets registered — call require('prompt').setup()")
  else
    for _, def in ipairs(targets) do
      vim.health.ok(def.display_name .. " (" .. def.name .. ")")
    end
  end

  vim.health.start("Connectors")
  local connector_names = require("prompt.connectors").list()
  for _, name in ipairs(connector_names) do
    local c = require("prompt.connectors").get(name)
    if c.available and c.available() then
      vim.health.ok(name .. " executable found")
    else
      vim.health.info(name .. " executable not found (completion still works from config dirs)")
    end
  end

  vim.health.start("Configuration")
  local env = vim.env.PROMPT_NVIM_TARGET
  if env and not require("prompt.bridge").in_bridge_mode() then
    vim.health.info("PROMPT_NVIM_TARGET set outside bridge mode: " .. env)
  else
    vim.health.ok("environment sane")
  end
end

return M
