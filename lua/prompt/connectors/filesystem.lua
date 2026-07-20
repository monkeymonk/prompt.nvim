local M = {}

local cache = require("prompt.cache")

local function has(exe)
  return vim.fn.executable(exe) == 1
end

local function split_lines(s)
  local out = {}
  for line in s:gmatch("[^\n]+") do
    table.insert(out, line)
  end
  return out
end

local function derive_dirs(files)
  local seen = {}
  local dirs = {}
  for _, path in ipairs(files) do
    local parts = {}
    for part in path:gmatch("[^/]+") do
      table.insert(parts, part)
    end
    local prefix = nil
    for i = 1, #parts - 1 do
      prefix = prefix and (prefix .. "/" .. parts[i]) or parts[i]
      if not seen[prefix] then
        seen[prefix] = true
        table.insert(dirs, prefix)
      end
    end
  end
  return dirs
end

local function cap(list, n)
  if n == nil then
    return list
  end
  local out = {}
  for i = 1, math.min(#list, n) do
    table.insert(out, list[i])
  end
  return out
end

function M.list(root, opts, callback)
  local key = ("fs:%s:h=%s:gi=%s"):format(root, tostring(opts.include_hidden), tostring(opts.respect_gitignore))

  local cached = cache.get(key)
  if cached ~= nil then
    callback(cached)
    return
  end

  local function finish(result)
    cache.set(key, result)
    callback(result)
  end

  if has("fd") then
    local function build_args(type_flag)
      local args = { "fd", "--type", type_flag, "--strip-cwd-prefix", "--max-results", tostring(opts.max_results) }
      if opts.include_hidden then
        table.insert(args, "--hidden")
      end
      if not opts.respect_gitignore then
        table.insert(args, "--no-ignore")
      end
      for _, ig in ipairs(opts.ignore or {}) do
        table.insert(args, "--exclude")
        table.insert(args, ig)
      end
      return args
    end

    local parsed_files, parsed_dirs
    local pending = 2

    vim.system(build_args("f"), { cwd = root, text = true }, function(obj)
      local stdout = obj.code == 0 and (obj.stdout or "") or ""
      parsed_files = split_lines(stdout)
      pending = pending - 1
      if pending == 0 then
        finish({ files = parsed_files, directories = parsed_dirs })
      end
    end)

    vim.system(build_args("d"), { cwd = root, text = true }, function(obj)
      local stdout = obj.code == 0 and (obj.stdout or "") or ""
      parsed_dirs = split_lines(stdout)
      pending = pending - 1
      if pending == 0 then
        finish({ files = parsed_files, directories = parsed_dirs })
      end
    end)
  elseif has("rg") then
    local args = { "rg", "--files" }
    if opts.include_hidden then
      table.insert(args, "--hidden")
    end
    if not opts.respect_gitignore then
      table.insert(args, "--no-ignore")
    end

    vim.system(args, { cwd = root, text = true }, function(obj)
      local files = cap(split_lines(obj.stdout or ""), opts.max_results)
      local directories = cap(derive_dirs(files), opts.max_results)
      finish({ files = files, directories = directories })
    end)
  elseif has("git") and vim.uv.fs_stat(root .. "/.git") then
    vim.system({ "git", "-C", root, "ls-files" }, { text = true }, function(obj)
      local files = cap(split_lines(obj.stdout or ""), opts.max_results)
      local directories = cap(derive_dirs(files), opts.max_results)
      finish({ files = files, directories = directories })
    end)
  else
    local ignore_set = {}
    for _, ig in ipairs(opts.ignore or {}) do
      ignore_set[ig] = true
    end

    local files = {}
    local dirs = {}
    local max_depth = opts.max_depth or 6

    local function walk(dir, rel, depth)
      if #files >= opts.max_results then
        return
      end
      if depth > max_depth then
        return
      end

      local ok, iter = pcall(vim.fs.dir, dir)
      if not ok or not iter then
        return
      end

      for name, type in iter do
        if #files >= opts.max_results then
          break
        end

        local skip = ignore_set[name] or (name:sub(1, 1) == "." and not opts.include_hidden)

        if not skip then
          local entry_rel = rel ~= "" and (rel .. "/" .. name) or name
          local entry_abs = dir .. "/" .. name

          if type == "directory" then
            table.insert(dirs, entry_rel)
            walk(entry_abs, entry_rel, depth + 1)
          elseif type == "file" then
            table.insert(files, entry_rel)
          end
        end
      end
    end

    walk(root, "", 1)

    finish({ files = cap(files, opts.max_results), directories = cap(dirs, opts.max_results) })
  end
end

-- Decide how to complete a path query. A bare term (no "/", not "~") uses the
-- recursive repo scan (M.list). Anything path-like (contains "/", or starts with
-- "~") switches to segment mode: list the immediate entries of the directory the
-- prefix points at. This is what makes "@../", "@/home/", "@~/" and "@src/" work.
function M.resolve_query(root, query)
  query = query or ""
  local is_home = query:sub(1, 1) == "~"

  local last
  for i = #query, 1, -1 do
    if query:sub(i, i) == "/" then
      last = i
      break
    end
  end

  local prefix, base
  if last then
    prefix = query:sub(1, last)
    base = query:sub(last + 1)
  elseif is_home then
    prefix = "~/"
    base = ""
  else
    return { mode = "repo" }
  end

  local first = query:sub(1, 1)
  local dir
  if first == "/" then
    dir = prefix
  elseif first == "~" then
    dir = vim.fn.expand(prefix)
  else
    dir = vim.fs.normalize(root .. "/" .. prefix)
  end
  -- Strip a trailing slash (except for the filesystem root "/") so fs_scandir
  -- receives a clean directory path.
  if #dir > 1 then
    dir = dir:gsub("/$", "")
  end

  return { mode = "segment", dir = dir, prefix = prefix, base = base }
end

-- List the immediate children of a single directory (non-recursive), resolving
-- symlinks to their target type. Cached briefly.
function M.list_dir(dir, callback)
  local key = "dir:" .. dir
  local cached = cache.get(key)
  if cached ~= nil then
    callback(cached)
    return
  end

  local entries = {}
  local handle = vim.uv.fs_scandir(dir)
  if handle then
    while true do
      local name, ty = vim.uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if ty == "link" then
        local st = vim.uv.fs_stat(dir .. "/" .. name)
        ty = st and st.type or "file"
      end
      entries[#entries + 1] = { name = name, type = ty }
    end
  end

  cache.set(key, entries, 5000)
  callback(entries)
end

function M.invalidate(root)
  cache.invalidate_project(root)
end

return M
