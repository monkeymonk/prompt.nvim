-- Absolute so module loading survives tests that change the cwd.
local tests_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")

local module_names = {
  "trigger",
  "ranking",
  "root",
  "cache",
  "candidate",
  "frontmatter",
  "registry",
  "pathspec",
  "shell",
  "cmp",
  "integration",
  "completion_race",
  "backend_parity",
}

local passed = 0
local failed = 0

-- Write unbuffered so headless output doesn't stall the event loop when piped.
local function say(line)
  io.stdout:write(line .. "\n")
  io.stdout:flush()
end

for _, name in ipairs(module_names) do
  local mod = dofile(tests_dir .. "/unit/" .. name .. ".lua")
  for test_name, fn in pairs(mod) do
    local ok, err = pcall(fn)
    if ok then
      passed = passed + 1
      say("ok - " .. name .. "/" .. test_name)
    else
      failed = failed + 1
      say("not ok - " .. name .. "/" .. test_name .. ": " .. tostring(err))
    end
  end
end

say(passed .. " passed, " .. failed .. " failed")

if failed > 0 then
  vim.cmd("cquit 1")
else
  say("ALL_TESTS_OK")
  vim.cmd("quitall!")
end
