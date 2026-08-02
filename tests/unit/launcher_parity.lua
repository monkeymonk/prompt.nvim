local assert = assert

local M = {}

-- The launcher must run standalone, with no Neovim available and fast enough
-- to sit in a shell rc behind `eval "$(prompt-nvim --print-shell zsh)"`. It
-- therefore cannot ask the registry which targets exist, and carries its own
-- SHELL_TARGETS list. That duplication is deliberate, but it must not drift
-- silently -- a target added to `register_builtins` and forgotten in the
-- launcher simply never gets a shell wrapper, with nothing to signal it.
--
-- Both lists are read as text rather than from the live registry: unit tests
-- run in one shared nvim in nondeterministic order, and other modules register
-- and unregister temporary targets.

local function read_runtime_file(relative)
  local path = vim.api.nvim_get_runtime_file(relative, false)[1]
  assert(path, "could not locate " .. relative .. " on the runtimepath")
  return table.concat(vim.fn.readfile(path), "\n")
end

local function sorted(list)
  local copy = vim.deepcopy(list)
  table.sort(copy)
  return copy
end

-- SHELL_TARGETS="claude codex gemini opencode pi"
local function launcher_targets()
  local body = read_runtime_file("bin/prompt-nvim")
  local list = body:match('\nSHELL_TARGETS="([^"]*)"')
  assert(list, "could not find SHELL_TARGETS in bin/prompt-nvim")

  local names = {}
  for name in list:gmatch("%S+") do
    names[#names + 1] = name
  end
  return sorted(names)
end

-- for _, name in ipairs({ "claude", "codex", ... }) do
local function builtin_targets()
  local body = read_runtime_file("lua/prompt/init.lua")
  local block = body:match("local function register_builtins%(%).-ipairs%(%{(.-)%}%)")
  assert(block, "could not find the register_builtins target list in lua/prompt/init.lua")

  local names = {}
  for name in block:gmatch('"([^"]+)"') do
    names[#names + 1] = name
  end
  return sorted(names)
end

function M.test_launcher_shell_targets_match_builtin_targets()
  local from_launcher = launcher_targets()
  local from_plugin = builtin_targets()

  assert(#from_launcher > 0, "expected a non-empty SHELL_TARGETS")
  assert(
    vim.deep_equal(from_launcher, from_plugin),
    string.format(
      "bin/prompt-nvim SHELL_TARGETS and lua/prompt/init.lua register_builtins have drifted.\n"
        .. "  launcher: %s\n  plugin:   %s\n"
        .. "Add the target to both, or the new target gets no shell wrapper.",
      table.concat(from_launcher, " "),
      table.concat(from_plugin, " ")
    )
  )
end

-- Guards the other direction: the names must be real registered targets, so a
-- typo in either list fails rather than producing a wrapper for a target that
-- cannot resolve.
function M.test_launcher_shell_targets_are_registered()
  require("prompt").setup({})
  local registry = require("prompt.registry")

  for _, name in ipairs(launcher_targets()) do
    assert(
      registry.has(name),
      "SHELL_TARGETS lists '" .. name .. "', which is not a registered target"
    )
  end
end

return M
