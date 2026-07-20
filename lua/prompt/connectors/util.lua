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

return M
