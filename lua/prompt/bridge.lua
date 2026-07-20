local M = {}

function M.in_bridge_mode()
  return vim.env.PROMPT_NVIM_BRIDGE == "1"
end

function M.is_bridge_buffer(bufnr)
  return vim.b[bufnr or 0].prompt_bridge == true
end

function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  vim.b[bufnr].prompt_original_content = table.concat(lines, "\n")
  vim.b[bufnr].prompt_original_path = vim.api.nvim_buf_get_name(bufnr)
  vim.b[bufnr].prompt_bridge = true

  M.setup_keymaps(bufnr)
end

function M.setup_keymaps(bufnr)
  local km = require("prompt.config").get().keymaps

  if km.return_prompt then
    vim.keymap.set({ "n", "i" }, km.return_prompt, function()
      M.return_prompt(bufnr)
    end, { buffer = bufnr, desc = "Prompt: save and return", silent = true })
  end

  if km.cancel_prompt then
    vim.keymap.set({ "n" }, km.cancel_prompt, function()
      M.cancel(bufnr)
    end, { buffer = bufnr, desc = "Prompt: cancel and restore", silent = true })
  end
end

function M.return_prompt(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok = pcall(vim.cmd, "silent write")
  if not ok then
    require("prompt.log").warn("failed to write buffer")
    return
  end

  if not require("prompt.config").get().bridge.close_on_return then
    return
  end

  if vim.env.PROMPT_NVIM_SERVER and vim.env.PROMPT_NVIM_SERVER ~= "" then
    pcall(vim.cmd, "bdelete")
  else
    vim.cmd("quitall")
  end
end

function M.cancel(bufnr, strategy)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  strategy = strategy or require("prompt.config").get().bridge.cancel_strategy or "restore"

  if strategy == "restore" then
    local orig = vim.b[bufnr].prompt_original_content or ""
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(orig, "\n", { plain = true }))
    M.return_prompt(bufnr)
  elseif strategy == "delete" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })
    M.return_prompt(bufnr)
  elseif strategy == "error-exit" then
    pcall(vim.cmd, "cquit")
  else
    require("prompt.log").warn("unknown cancel strategy: " .. tostring(strategy))
    local orig = vim.b[bufnr].prompt_original_content or ""
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(orig, "\n", { plain = true }))
    M.return_prompt(bufnr)
  end
end

return M
