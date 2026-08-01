local M = {}

function M.is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

-- Scan a directory tree for *.md entries, emitting candidates of the given
-- kind. Shared by the command/agent/prompt scanners (they differ only in kind
-- and recursion depth).
local function scan_md(dir, scope, source_name, out, kind, depth)
  if not M.is_dir(dir) then
    return
  end
  pcall(function()
    local frontmatter = require("prompt.frontmatter")
    for name, ty in vim.fs.dir(dir, { depth = depth or 5 }) do
      if ty == "file" and name:match("%.md$") then
        local rel = name:gsub("%.md$", "")
        local path = dir .. "/" .. name
        local fm = frontmatter.parse(path)
        table.insert(out, {
          label = rel,
          insert_text = rel,
          kind = kind,
          source = source_name,
          scope = scope,
          detail = kind .. " · " .. scope,
          documentation = fm.description,
          path = path,
        })
      end
    end
  end)
end

function M.scan_md_commands(dir, scope, source_name, out)
  scan_md(dir, scope, source_name, out, "command")
end

function M.scan_toml_commands(dir, scope, source_name, out)
  if not M.is_dir(dir) then
    return
  end
  pcall(function()
    for name, ty in vim.fs.dir(dir, { depth = 5 }) do
      if ty == "file" and name:match("%.toml$") then
        local rel = name:gsub("%.toml$", ""):gsub("/", ":")
        local path = dir .. "/" .. name
        local documentation
        local ok, lines = pcall(vim.fn.readfile, path, "", 40)
        if ok and lines then
          for _, line in ipairs(lines) do
            local value = line:match("^%s*description%s*=%s*(.+)$")
            if value then
              value = value:gsub("%s+$", "")
              local quoted = value:match('^"(.*)"$') or value:match("^'(.*)'$")
              documentation = quoted or value
              break
            end
          end
        end
        table.insert(out, {
          label = rel,
          insert_text = rel,
          kind = "command",
          source = source_name,
          scope = scope,
          detail = "command · " .. scope,
          documentation = documentation,
          path = path,
        })
      end
    end
  end)
end

function M.scan_skills(dir, scope, source_name, out)
  if not M.is_dir(dir) then
    return
  end
  pcall(function()
    local frontmatter = require("prompt.frontmatter")
    for name, ty in vim.fs.dir(dir) do
      if ty == "directory" then
        local sm = dir .. "/" .. name .. "/SKILL.md"
        if vim.uv.fs_stat(sm) then
          local fm = frontmatter.parse(sm)
          local label = fm.name or name
          table.insert(out, {
            label = label,
            insert_text = label,
            kind = "skill",
            source = source_name,
            scope = scope,
            detail = "skill · " .. scope,
            documentation = fm.description,
            path = sm,
          })
        end
      end
    end
  end)
end

function M.scan_agents(dir, scope, source_name, out)
  scan_md(dir, scope, source_name, out, "agent", 2)
end

function M.scan_md_prompts(dir, scope, source_name, out)
  scan_md(dir, scope, source_name, out, "prompt")
end

-- Run connector filesystem work in bounded scheduled chunks. The iterator and
-- output order are kept per root so this preserves the synchronous scanners'
-- project-before-user ordering while yielding to the editor between chunks.
function M.scan_async(specs, callback)
  local out = {}
  local cancelled = false
  local finished = false
  local spec_index = 1
  local iterator
  local scan_spec

  local function finish()
    if finished or cancelled then
      return
    end
    finished = true
    callback(out)
  end

  local function emit(name, ty)
    local spec = scan_spec
    if spec.scanner == "skills" then
      if ty ~= "directory" then return end
      local path = spec.path .. "/" .. name .. "/SKILL.md"
      if not vim.uv.fs_stat(path) then return end
      local fm = require("prompt.frontmatter").parse(path)
      local label = fm.name or name
      out[#out + 1] = {
        label = label, insert_text = label, kind = "skill", source = spec.source_name,
        scope = spec.scope, detail = "skill · " .. spec.scope, documentation = fm.description, path = path,
      }
    elseif ty == "file" then
      local kind = spec.scanner == "md_commands" and "command"
        or spec.scanner == "md_agents" and "agent"
        or spec.scanner == "md_prompts" and "prompt"
      if spec.scanner == "toml_commands" and name:match("%.toml$") then
        local path = spec.path .. "/" .. name
        local documentation
        local ok, lines = pcall(vim.fn.readfile, path, "", 40)
        if ok and lines then
          for _, line in ipairs(lines) do
            local value = line:match("^%s*description%s*=%s*(.+)$")
            if value then
              value = value:gsub("%s+$", "")
              documentation = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
              break
            end
          end
        end
        out[#out + 1] = {
          label = name:gsub("%.toml$", ""):gsub("/", ":"), insert_text = name:gsub("%.toml$", ""):gsub("/", ":"),
          kind = "command", source = spec.source_name, scope = spec.scope,
          detail = "command · " .. spec.scope, documentation = documentation, path = path,
        }
      elseif kind and name:match("%.md$") then
        local path = spec.path .. "/" .. name
        local fm = require("prompt.frontmatter").parse(path)
        local label = name:gsub("%.md$", "")
        out[#out + 1] = {
          label = label, insert_text = label, kind = kind, source = spec.source_name,
          scope = spec.scope, detail = kind .. " · " .. spec.scope, documentation = fm.description, path = path,
        }
      end
    end
  end

  local function step()
    if cancelled or finished then return end
    if iterator == nil then
      scan_spec = specs[spec_index]
      if not scan_spec then return finish() end
      spec_index = spec_index + 1
      if not M.is_dir(scan_spec.path) then
        return vim.schedule(step)
      end
      local depth = scan_spec.depth
        or (scan_spec.scanner == "skills" and 1)
        or (scan_spec.scanner == "md_agents" and 2)
        or 5
      local ok, iter = pcall(vim.fs.dir, scan_spec.path, { depth = depth })
      if not ok then
        return vim.schedule(step)
      end
      iterator = iter
    end

    local count = 0
    while count < 32 do
      local ok, name, ty = pcall(iterator)
      if not ok or name == nil then
        iterator = nil
        return vim.schedule(step)
      end
      pcall(emit, name, ty)
      count = count + 1
    end
    vim.schedule(step)
  end

  vim.schedule(step)
  return function()
    cancelled = true
  end
end

-- C5: connector output contract. Every connector's `discover()` is expected to
-- produce items shaped like:
--   { label=, insert_text=, kind=, scope=, source_path=, documentation= }
-- `source_path` is carried on the item as `path` (candidate.lua/ranking.lua
-- read `item.path` for open-buffer boosting and are not owned by this
-- package), so validation accepts either `item.source_path` or `item.path`
-- and normalizes both onto the item.
local VALID_KINDS = { command = true, skill = true, agent = true, prompt = true }

-- Validate a single connector-produced item. Returns `(normalized_item, nil)`
-- on success or `(nil, err)` on failure, where `err` names the offending
-- field.
function M.validate_item(item)
  if type(item) ~= "table" then
    return nil, "item is not a table"
  end
  if type(item.label) ~= "string" or item.label == "" then
    return nil, "invalid or missing field: label"
  end
  if item.insert_text ~= nil and type(item.insert_text) ~= "string" then
    return nil, "invalid field: insert_text"
  end
  if type(item.kind) ~= "string" or not VALID_KINDS[item.kind] then
    return nil, "invalid or missing field: kind (" .. tostring(item.kind) .. ")"
  end
  if item.scope ~= nil and type(item.scope) ~= "string" then
    return nil, "invalid field: scope"
  end
  local source_path = item.source_path or item.path
  if source_path ~= nil and type(source_path) ~= "string" then
    return nil, "invalid field: source_path"
  end
  if
    item.documentation ~= nil
    and type(item.documentation) ~= "string"
    and type(item.documentation) ~= "table"
  then
    return nil, "invalid field: documentation"
  end

  local normalized = {}
  for key, value in pairs(item) do
    normalized[key] = value
  end
  normalized.insert_text = item.insert_text or item.label
  normalized.source_path = source_path
  normalized.path = source_path
  return normalized, nil
end

-- Drop and debug-log invalid items; cap the count at
-- `completion.max_items_per_source` (defense in depth — the completion
-- aggregator also enforces this cap, but a single connector should not be
-- able to build an unbounded table before it gets there).
function M.normalize_items(list)
  local out = {}
  if type(list) ~= "table" then
    return out
  end
  local cap = require("prompt.config").get().completion.max_items_per_source
  for _, item in ipairs(list) do
    local normalized, err = M.validate_item(item)
    if normalized then
      table.insert(out, normalized)
      if cap and #out >= cap then
        break
      end
    else
      require("prompt.log").debug("connector item dropped: " .. tostring(err))
    end
  end
  return out
end

return M
