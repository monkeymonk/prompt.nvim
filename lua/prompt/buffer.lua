local M = {}

local function env(name)
  local v = vim.env[name]
  if v and v ~= "" then
    return v
  end
  return nil
end

function M.is_attached(bufnr)
  return require("prompt.session").is_active(bufnr or 0)
end

-- M.attach(bufnr, target, extra) — builds the buffer-local session (C1) and
-- sets up buffer options/keymaps. `extra` (optional) carries session fields
-- that the caller already knows (used by `prompt.remote` for existing-server
-- sessions: id/launch_cwd/root/remote/backup_path/original_path); anything it
-- omits falls back to the fresh-process detection below.
function M.attach(bufnr, target, extra)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  extra = extra or {}
  local cfg = require("prompt.config").get()

  vim.bo[bufnr].filetype = cfg.buffer.filetype
  vim.bo[bufnr].swapfile = cfg.buffer.swapfile

  -- Fresh (VimEnter) buffers: the launcher exports the TOOL's project dir as
  -- PROMPT_NVIM_CWD (NOT nvim's own getcwd()). Remote/server sessions pass
  -- launch_cwd explicitly via `extra`.
  local launch_cwd = extra.launch_cwd or env("PROMPT_NVIM_CWD") or vim.fn.getcwd()
  local root = extra.root or require("prompt.root").detect(launch_cwd)

  require("prompt.session").create(bufnr, {
    id = extra.id,
    target = target,
    launch_cwd = launch_cwd,
    root = root,
    bridge = extra.bridge,
    remote = extra.remote,
    original_path = extra.original_path or vim.api.nvim_buf_get_name(bufnr),
    backup_path = extra.backup_path,
  })

  -- Legacy per-buffer var kept in sync: `prompt.target`'s per-buffer override
  -- lookup reads `vim.b[bufnr].prompt_target` directly and is outside this
  -- work package's file ownership, so it can't be migrated to the session
  -- table here.
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

  -- A prompt buffer with no resolvable target is inert, and silently so: every
  -- trigger parse bails early (`prompt.trigger.parse` returns nil without a
  -- target definition), so completion returns zero items forever while the
  -- buffer, the blink/cmp source and `:checkhealth prompt` all still look
  -- healthy. Warn instead, naming the ways to set one. Routed through
  -- `prompt.log` so `log.level` can silence it.
  if require("prompt.target").resolve(bufnr) == nil then
    require("prompt.log").warn(
      "no target for this buffer - completion will return nothing. "
        .. "Set PROMPT_NVIM_TARGET (see `prompt-nvim --print-shell`), "
        .. "`default_target` in setup(), or run :PromptTarget <name>."
    )
  end
end

function M.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  require("prompt.session").clear(bufnr)
  vim.b[bufnr].prompt_target = nil
end

return M
