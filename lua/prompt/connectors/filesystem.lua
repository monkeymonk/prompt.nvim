-- Canonical file-discovery contract: return tracked and untracked files (and
-- their parent directories) beneath `root`, excluding ignored files and
-- `opts.ignore` exclusions, with consistent hidden-file behavior governed by
-- `opts.include_hidden`. Every backend (fd/rg/git/pure-Lua walk) below is
-- expected to approximate this same result set for a given root/opts.
--
-- Known divergence: with `opts.follow_symlinks = false`, fd/rg/lua exclude
-- symlinked files, but the git backend (`ls-files`) still lists a tracked
-- symlink. This is a minor cross-backend cosmetic difference (the symlink is a
-- real, valid path) and is left as-is rather than paying an fs_lstat per file.
local M = {}

local cache = require("prompt.cache")
local log = require("prompt.log")

local function has(exe)
  return vim.fn.executable(exe) == 1
end

-- Split a null-delimited byte string into a list of non-empty entries.
local function split_nul(s)
  local out = {}
  if not s or s == "" then
    return out
  end
  for part in (s .. "\0"):gmatch("([^%z]*)%z") do
    if part ~= "" then
      table.insert(out, part)
    end
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

-- Post-filter a file list against opts.ignore (path-segment match) and
-- opts.include_hidden (dotfile/dotdir segment match). Used by backends that
-- cannot express these natively (git).
local function post_filter(list, opts)
  local ignore_set = {}
  for _, ig in ipairs(opts.ignore or {}) do
    ignore_set[ig] = true
  end
  if next(ignore_set) == nil and opts.include_hidden then
    return list
  end

  local out = {}
  for _, rel in ipairs(list) do
    local skip = false
    for part in rel:gmatch("[^/]+") do
      if ignore_set[part] or (not opts.include_hidden and part:sub(1, 1) == ".") then
        skip = true
        break
      end
    end
    if not skip then
      table.insert(out, rel)
    end
  end
  return out
end

local function stable_join(list)
  if not list or #list == 0 then
    return ""
  end
  local sorted = vim.deepcopy(list)
  table.sort(sorted)
  return table.concat(sorted, ",")
end

local function cache_key(root, opts, backend)
  return ("fs:%s:h=%s:gi=%s:ig=%s:d=%s:n=%s:be=%s"):format(
    root,
    tostring(opts.include_hidden),
    tostring(opts.respect_gitignore),
    stable_join(opts.ignore),
    tostring(opts.max_depth),
    tostring(opts.max_results),
    tostring(backend)
  )
end

-- In-flight request dedup, keyed by the full cache key. Concurrent identical
-- requests share a single underlying scan.
local inflight = {}

function M.list(root, opts, callback)
  local backend
  if has("fd") then
    backend = "fd"
  elseif has("rg") then
    backend = "rg"
  elseif has("git") and vim.uv.fs_stat(root .. "/.git") then
    backend = "git"
  elseif opts.respect_gitignore and has("git") then
    -- No fd/rg, but git is present: the pure-Lua fallback below cannot honor
    -- .gitignore, so prefer the git backend when gitignore filtering matters.
    backend = "git"
  else
    if opts.respect_gitignore then
      log.debug("filesystem: no fd/rg/git available; pure-Lua fallback does not honor .gitignore")
    end
    backend = "lua"
  end

  local key = cache_key(root, opts, backend)

  local cached = cache.get(key)
  if cached ~= nil then
    callback(cached)
    return function() end
  end

  local existing = inflight[key]
  if existing then
    local idx = #existing.callbacks + 1
    existing.callbacks[idx] = callback
    local unsubscribed = false
    return function()
      if unsubscribed then
        return
      end
      unsubscribed = true
      existing.callbacks[idx] = false
    end
  end

  local entry = { callbacks = { callback }, cancel = nil, done = false }
  inflight[key] = entry

  local cancelled = false

  local function finish(result, ok)
    if entry.done then
      return
    end
    entry.done = true
    inflight[key] = nil
    -- Only cache a scan that exited cleanly and was not cancelled/killed/timed
    -- out; caching a partial/empty result from a killed process would poison
    -- the cache for later requests. Still fan out so callers never hang.
    if ok ~= false and not cancelled then
      cache.set(key, result)
    end
    for _, cb in ipairs(entry.callbacks) do
      if cb then
        cb(result)
      end
    end
  end

  local function cancel_all()
    if cancelled then
      return
    end
    cancelled = true
    if entry.cancel then
      entry.cancel()
    end
  end

  if backend == "fd" then
    local function build_args(type_flag)
      local args = { "fd", "--type", type_flag, "--print0", "--strip-cwd-prefix" }
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
    local procs = {}

    local function on_done()
      pending = pending - 1
      if pending == 0 then
        finish({
          files = cap(parsed_files or {}, opts.max_results),
          directories = cap(parsed_dirs or {}, opts.max_results),
        })
      end
    end

    procs[1] = vim.system(
      build_args("f"),
      { cwd = root, text = true, timeout = opts.scan_timeout_ms },
      function(obj)
        local stdout = obj.code == 0 and (obj.stdout or "") or ""
        parsed_files = split_nul(stdout)
        on_done()
      end
    )

    procs[2] = vim.system(
      build_args("d"),
      { cwd = root, text = true, timeout = opts.scan_timeout_ms },
      function(obj)
        local stdout = obj.code == 0 and (obj.stdout or "") or ""
        -- fd's `--type d` output carries a trailing slash ("nested/"); the
        -- directory contract (like derive_dirs) is slash-free, so strip it to
        -- keep fd consistent with the rg/git/lua backends.
        parsed_dirs = {}
        for _, d in ipairs(split_nul(stdout)) do
          parsed_dirs[#parsed_dirs + 1] = (d:gsub("/+$", ""))
        end
        on_done()
      end
    )

    entry.cancel = function()
      for _, p in ipairs(procs) do
        pcall(function()
          p:kill(9)
        end)
      end
    end
  elseif backend == "rg" then
    local args = { "rg", "--files", "-0" }
    if opts.include_hidden then
      table.insert(args, "--hidden")
    end
    if not opts.respect_gitignore then
      table.insert(args, "--no-ignore")
    end
    for _, ig in ipairs(opts.ignore or {}) do
      table.insert(args, "-g")
      table.insert(args, "!" .. ig)
    end

    local proc = vim.system(
      args,
      { cwd = root, text = true, timeout = opts.scan_timeout_ms },
      function(obj)
        local files = cap(split_nul(obj.stdout or ""), opts.max_results)
        local directories = cap(derive_dirs(files), opts.max_results)
        finish({ files = files, directories = directories })
      end
    )
    entry.cancel = function()
      pcall(function()
        proc:kill(9)
      end)
    end
  elseif backend == "git" then
    local proc = vim.system(
      { "git", "-C", root, "ls-files", "-z", "--cached", "--others", "--exclude-standard" },
      { text = true, timeout = opts.scan_timeout_ms },
      function(obj)
        local files = post_filter(split_nul(obj.stdout or ""), opts)
        files = cap(files, opts.max_results)
        local directories = cap(derive_dirs(files), opts.max_results)
        finish({ files = files, directories = directories })
      end
    )
    entry.cancel = function()
      pcall(function()
        proc:kill(9)
      end)
    end
  else
    local ignore_set = {}
    for _, ig in ipairs(opts.ignore or {}) do
      ignore_set[ig] = true
    end

    local files = {}
    local dirs = {}
    local max_depth = opts.max_depth or 6
    local max_entries = opts.max_entries_scanned or math.huge
    local scanned = 0
    local visited_real = {}
    local stopped = false

    local function walk(dir, rel, depth)
      if stopped or #files >= opts.max_results then
        return
      end
      if depth > max_depth then
        return
      end

      if not opts.follow_symlinks then
        local real = vim.uv.fs_realpath(dir)
        if real then
          if visited_real[real] then
            return
          end
          visited_real[real] = true
        end
      end

      local ok, iter = pcall(vim.fs.dir, dir)
      if not ok or not iter then
        return
      end

      for name, type in iter do
        if stopped or #files >= opts.max_results then
          break
        end

        scanned = scanned + 1
        if scanned > max_entries then
          if not stopped then
            log.debug("filesystem: pure-Lua walk exceeded max_entries_scanned; stopping early")
          end
          stopped = true
          break
        end

        -- Skip ignored/hidden entries, and symlinks when follow_symlinks is off
        -- (never descend or classify them).
        local skip = ignore_set[name]
          or (name:sub(1, 1) == "." and not opts.include_hidden)
          or (type == "link" and not opts.follow_symlinks)

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
    entry.cancel = function() end
  end

  return cancel_all
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
    return function() end
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
  return function() end
end

function M.invalidate(root)
  cache.invalidate_project(root)
end

return M
