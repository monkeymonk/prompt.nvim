local M = {}
M.name = "shell"

-- Everything typed after the leading "!" up to the cursor.
local function command_line(before)
  return (before:gsub("^%s*!%s*", ""))
end

-- True while the cursor is still on the command name (the first word after "!").
local function is_first_word(before)
  local cmd = command_line(before)
  local trailing = cmd:match("%S*$") or ""
  return #cmd == #trailing
end

-- Complete executables found on $PATH (cached briefly).
local function complete_commands(_ctx, callback)
  local cache = require("prompt.cache")
  local names = cache.get("shell:commands")
  if not names then
    names = {}
    local seen = {}
    for dir in (vim.env.PATH or ""):gmatch("[^:]+") do
      local handle = vim.uv.fs_scandir(dir)
      if handle then
        while true do
          local name, ty = vim.uv.fs_scandir_next(handle)
          if not name then
            break
          end
          if (ty == "file" or ty == "link") and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
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
local function complete_paths(ctx, callback)
  local fs = require("prompt.connectors.filesystem")
  local base = ctx.cwd or ctx.root or vim.fn.getcwd()
  local spec = fs.resolve_query(base, ctx.query)
  local dir, prefix
  if spec.mode == "segment" then
    dir, prefix = spec.dir, spec.prefix
  else
    dir, prefix = base, ""
  end

  local word_base = ctx.query:match("[^/]*$") or ""
  local show_hidden = word_base:sub(1, 1) == "."

  fs.list_dir(dir, function(entries)
    local items = {}
    for _, e in ipairs(entries) do
      if show_hidden or e.name:sub(1, 1) ~= "." then
        local slash = e.type == "directory" and "/" or ""
        local full = prefix .. e.name .. slash
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
  if is_first_word(ctx.before_cursor) then
    complete_commands(ctx, callback)
  else
    complete_paths(ctx, callback)
  end
end

return M
