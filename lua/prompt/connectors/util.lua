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

  local normalized = vim.deepcopy(item)
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
