local M = {}

function M.build(bufnr, winid)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winid = winid or vim.api.nvim_get_current_win()

  local cursor = vim.api.nvim_win_get_cursor(winid)
  local row, col = cursor[1], cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local before = line:sub(1, col)
  local after = line:sub(col + 1)

  local target = require("prompt.target").resolve(bufnr)
  local cwd = vim.fn.getcwd()

  -- Choose the directory to detect the project root from. In bridge mode the
  -- buffer is a temporary prompt file the AI tool stores elsewhere (e.g. under
  -- ~/.claude/projects/...), so walking up from it would find the wrong root
  -- (~/.claude). The real project is the directory the tool was launched from,
  -- which nvim inherits as its cwd. For normal buffers, use the file's dir.
  local bridge = require("prompt.bridge").is_bridge_buffer(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local start
  if bridge or bufname == "" then
    start = cwd
  else
    start = vim.fn.fnamemodify(bufname, ":h")
  end
  local root = require("prompt.root").detect(start)

  return {
    bufnr = bufnr,
    winid = winid,
    target = target,
    cwd = cwd,
    root = root,
    line = line,
    row = row,
    col = col,
    before_cursor = before,
    after_cursor = after,
    query = "",
    bridge = bridge,
  }
end

return M
