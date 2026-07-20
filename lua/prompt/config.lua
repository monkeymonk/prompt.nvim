local M = {}

M.defaults = {
  default_target = nil,
  bridge = { enabled = true, cancel_strategy = "restore", close_on_return = true },
  buffer = { filetype = "markdown", wrap = true, linebreak = true, breakindent = true, spell = false, swapfile = false },
  keymaps = { return_prompt = "<C-CR>", cancel_prompt = nil, complete = "<C-x><C-a>" },
  completion = {
    min_query_length = 0,
    max_results = 100,
  },
  paths = {
    root_markers = { ".git", "CLAUDE.md", "AGENTS.md", "GEMINI.md" },
    include_hidden = false,
    respect_gitignore = true,
    max_results = 200,
    max_depth = nil,
    directory_trailing_slash = true,
    ignore = { ".git", "node_modules", "vendor", "dist", "build", "target", ".next", ".cache" },
  },
  cache = { enabled = true, ttl_ms = 30000 },
  highlight = { enabled = true },
  log = { level = "warn" },
  targets = {},
}

M.options = nil

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

function M.get()
  if M.options == nil then
    M.setup({})
  end
  return M.options
end

return M
