local shell_lex = require("prompt.sources.shell_lex")

local M = {}
M.name = "shell"

-- Everything typed after the leading "!" up to the cursor.
local function command_line(before)
  return (before:gsub("^%s*!%s*", ""))
end

-- Does `mode` (a raw stat.mode) have any of the user/group/other execute
-- bits set (0111 octal == 0x49)?
local function has_exec_bit(mode)
  if type(mode) ~= "number" then
    return false
  end
  local ok, bit = pcall(require, "bit")
  if ok and bit and bit.band then
    -- Neovim ships LuaJIT, which always provides `bit`.
    return bit.band(mode, 0x49) ~= 0
  end
  -- PUC Lua fallback (no native bitwise operators): test the other/group/
  -- owner execute bits (0x1, 0x8, 0x40) via arithmetic instead of bit.band.
  return (mode % 2 == 1) or (math.floor(mode / 8) % 2 == 1) or (math.floor(mode / 64) % 2 == 1)
end

-- Split a `--opt=value` style word into its option prefix (kept verbatim in
-- the inserted text) and the value to actually match/complete as a path.
local function split_option_value(word)
  local prefix = word:match("^%-%-[%w%-_]+=")
  if prefix then
    return prefix, word:sub(#prefix + 1)
  end
  return "", word
end

-- Complete executables found on $PATH (cached briefly).
local function complete_commands(_ctx, callback)
  local cache = require("prompt.cache")
  local names = cache.get("shell:commands")
  if not names then
    names = {}
    local seen = {}
    -- Empty PATH components (leading/trailing/doubled ":") are skipped, not
    -- treated as the current directory.
    for dir in (vim.env.PATH or ""):gmatch("[^:]+") do
      local handle = vim.uv.fs_scandir(dir)
      if handle then
        while true do
          local name = vim.uv.fs_scandir_next(handle)
          if not name then
            break
          end
          if not seen[name] then
            local stat = vim.uv.fs_stat(dir .. "/" .. name)
            if stat and stat.type ~= "directory" and has_exec_bit(stat.mode) then
              seen[name] = true
              names[#names + 1] = name
            end
          end
        end
      end
    end
    cache.set("shell:commands", names, 60000)
  end

  local items = {}
  for _, name in ipairs(names) do
    items[#items + 1] = { label = name, insert_text = name, kind = "command", source = "shell" }
  end
  callback(items)
end

-- Complete file/directory paths for the current argument word, relative to the
-- directory the tool was launched from (cwd), like a real shell.
local function complete_paths(ctx, cur, callback)
  local fs = require("prompt.connectors.filesystem")
  local base = ctx.cwd or ctx.root or vim.fn.getcwd()
  local opt_prefix, word = split_option_value(cur.current_word)
  local spec = fs.resolve_query(base, word)
  local dir, prefix
  if spec.mode == "segment" then
    dir, prefix = spec.dir, spec.prefix
  else
    dir, prefix = base, ""
  end

  local word_base = word:match("[^/]*$") or ""
  local show_hidden = word_base:sub(1, 1) == "."

  fs.list_dir(dir, function(entries)
    local items = {}
    for _, e in ipairs(entries) do
      if show_hidden or e.name:sub(1, 1) ~= "." then
        local slash = e.type == "directory" and "/" or ""
        local full = opt_prefix .. prefix .. e.name .. slash
        items[#items + 1] = {
          label = e.name .. slash,
          insert_text = full,
          filter_text = full,
          kind = e.type == "directory" and "directory" or "file",
          source = "shell",
          path = dir .. "/" .. e.name,
        }
      end
    end
    callback(items)
  end)
end

function M.complete(ctx, callback)
  local before = ctx.before_cursor or ("!" .. (ctx.query or ""))
  local cur = shell_lex.current(command_line(before))
  if cur.is_command_position then
    complete_commands(ctx, callback)
  else
    complete_paths(ctx, cur, callback)
  end
end

return M
