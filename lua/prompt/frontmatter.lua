local M = {}

function M.parse_lines(lines)
  local result = {}
  local ok = pcall(function()
    local i = 1
    while lines[i] and lines[i]:match("^%s*$") do
      i = i + 1
    end
    if not lines[i] or lines[i] ~= "---" then
      return
    end
    i = i + 1
    while lines[i] and lines[i] ~= "---" do
      local key, value = lines[i]:match("^(%w[%w%-_]*):%s*(.*)$")
      if key then
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        local quoted = value:match('^"(.*)"$') or value:match("^'(.*)'$")
        if quoted then
          value = quoted
        end
        result[key:lower()] = value
      end
      i = i + 1
    end
  end)
  if not ok then
    return {}
  end
  return result
end

function M.parse(path)
  local ok, lines = pcall(vim.fn.readfile, path, "", 40)
  if not ok or not lines then
    return {}
  end
  local pok, res = pcall(M.parse_lines, lines)
  if not pok then
    return {}
  end
  return res
end

return M
