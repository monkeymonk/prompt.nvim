local M = {}

function M.is_attached(bufnr)
  return vim.b[bufnr or 0].prompt_attached == true
end

function M.attach(bufnr, target)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = require("prompt.config").get()

  vim.bo[bufnr].filetype = cfg.buffer.filetype
  vim.bo[bufnr].swapfile = cfg.buffer.swapfile

  vim.b[bufnr].prompt_attached = true
  vim.b[bufnr].prompt_target = target

  local km = cfg.keymaps
  if km.complete then
    vim.keymap.set("i", km.complete, function()
      require("prompt.integrations.native").complete_insert()
    end, { buffer = bufnr, desc = "Prompt: complete", silent = true })
  end

  if bufnr == vim.api.nvim_get_current_buf() then
    vim.wo[0].wrap = cfg.buffer.wrap
    vim.wo[0].linebreak = cfg.buffer.linebreak
    vim.wo[0].breakindent = cfg.buffer.breakindent
    vim.wo[0].spell = cfg.buffer.spell
  end

  require("prompt.log").debug("attached buffer " .. bufnr .. " target=" .. tostring(target))
end

function M.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  vim.b[bufnr].prompt_attached = nil
  vim.b[bufnr].prompt_target = nil
  vim.b[bufnr].prompt_bridge = nil
  vim.b[bufnr].prompt_original_content = nil
  vim.b[bufnr].prompt_original_path = nil
end

return M
