local M = {}

-- Capture what `prompt.log` pushes through vim.notify while `fn` runs.
-- Tests run in one shared nvim and in nondeterministic order (`pairs`), so each
-- case restores vim.notify and PROMPT_NVIM_TARGET itself rather than relying on
-- ambient state.
local function captured_notifications(fn)
  local original_notify = vim.notify
  local original_env = vim.env.PROMPT_NVIM_TARGET
  local messages = {}

  vim.notify = function(msg)
    messages[#messages + 1] = msg
  end

  local ok, err = pcall(fn)

  vim.notify = original_notify
  vim.env.PROMPT_NVIM_TARGET = original_env

  if not ok then
    error(err)
  end
  return messages
end

local function has_no_target_warning(messages)
  for _, msg in ipairs(messages) do
    if msg:find("no target", 1, true) then
      return true
    end
  end
  return false
end

-- The regression this guards: a prompt buffer with no resolvable target still
-- attaches and still reports `is_attached`, but every trigger parse bails, so
-- completion returns nothing forever with no error anywhere.
function M.test_attach_without_any_target_warns()
  local messages = captured_notifications(function()
    vim.env.PROMPT_NVIM_TARGET = ""
    require("prompt").setup({})
    vim.cmd("enew")
    require("prompt.buffer").attach(0, nil)
  end)

  assert(
    has_no_target_warning(messages),
    "expected a 'no target' warning, got: " .. vim.inspect(messages)
  )
end

function M.test_attach_with_explicit_target_is_quiet()
  local messages = captured_notifications(function()
    vim.env.PROMPT_NVIM_TARGET = ""
    require("prompt").setup({})
    vim.cmd("enew")
    require("prompt.buffer").attach(0, "claude")
  end)

  assert(
    not has_no_target_warning(messages),
    "explicit target must not warn, got: " .. vim.inspect(messages)
  )
end

-- `default_target` is a legitimate way to supply the target, so it must not
-- trip the warning even though `attach` itself is passed nil.
function M.test_attach_falling_back_to_default_target_is_quiet()
  local messages = captured_notifications(function()
    vim.env.PROMPT_NVIM_TARGET = ""
    require("prompt").setup({ default_target = "codex" })
    vim.cmd("enew")
    require("prompt.buffer").attach(0, nil)
  end)

  assert(
    not has_no_target_warning(messages),
    "default_target must not warn, got: " .. vim.inspect(messages)
  )
end

function M.test_env_target_is_quiet()
  local messages = captured_notifications(function()
    vim.env.PROMPT_NVIM_TARGET = "gemini"
    require("prompt").setup({})
    vim.cmd("enew")
    require("prompt.buffer").attach(0, nil)
  end)

  assert(
    not has_no_target_warning(messages),
    "PROMPT_NVIM_TARGET must not warn, got: " .. vim.inspect(messages)
  )
end

-- The warning goes through `prompt.log`, so users who do not want it can turn
-- it off with the same `log.level` knob as every other plugin message.
function M.test_no_target_warning_respects_log_level()
  local messages = captured_notifications(function()
    vim.env.PROMPT_NVIM_TARGET = ""
    require("prompt").setup({ log = { level = "error" } })
    vim.cmd("enew")
    require("prompt.buffer").attach(0, nil)
  end)

  assert(
    not has_no_target_warning(messages),
    "log.level=error must silence it, got: " .. vim.inspect(messages)
  )
end

return M
