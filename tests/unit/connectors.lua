local M = {}

local function temp_root(name)
  local root = vim.fn.tempname() .. "-prompt-" .. name
  vim.fn.mkdir(root, "p")
  return root
end

local function write(path, lines)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(lines, path)
end

local function wait_for(predicate)
  assert(vim.wait(1000, predicate, 10), "connector discovery did not complete")
end

function M.test_discovery_does_not_require_executable()
  require("prompt.cache").clear()
  local root = temp_root("claude")
  write(root .. "/.claude/commands/review.md", { "---", "description: Review code", "---" })
  local result, calls = nil, 0
  require("prompt.connectors").get("claude").discover("commands", { root = root }, function(items)
    calls = calls + 1
    result = items
  end)
  wait_for(function()
    return result ~= nil
  end)
  assert(calls == 1, "connector callback must run once")
  assert(
    #result == 1 and result[1].label == "review",
    "configured connector files must be discoverable"
  )
end

function M.test_cache_keys_include_kind_root_and_opencode_config()
  local cache = require("prompt.cache")
  cache.clear()
  local connector = require("prompt.connectors").get("opencode")
  local project = temp_root("opencode-project")
  local config_a = temp_root("opencode-a")
  local config_b = temp_root("opencode-b")
  write(project .. "/.opencode/command/project.md", { "project" })
  write(config_a .. "/command/a.md", { "a" })
  write(config_b .. "/command/b.md", { "b" })

  local function discover(env_dir)
    vim.env.OPENCODE_CONFIG_DIR = env_dir
    local result
    connector.discover("commands", { root = project }, function(items)
      result = items
    end)
    wait_for(function()
      return result ~= nil
    end)
    return result
  end

  local a = discover(config_a)
  local b = discover(config_b)
  assert(#a == 2 and a[2].label == "a", "first config root must be represented in results")
  assert(#b == 2 and b[2].label == "b", "changed config root must not reuse stale cache")

  local skills
  connector.discover("skills", { root = project }, function(items)
    skills = items
  end)
  wait_for(function()
    return skills ~= nil
  end)
  assert(#skills == 0, "kind must have an independent cache entry")
end

function M.test_cancelled_discovery_does_not_cache_or_callback()
  local cache = require("prompt.cache")
  cache.clear()
  local root = temp_root("cancel")
  for i = 1, 80 do
    write(root .. "/.claude/commands/item" .. i .. ".md", { "item" })
  end
  local called = false
  local cancel = require("prompt.connectors")
    .get("claude")
    .discover("commands", { root = root }, function()
      called = true
    end)
  cancel()
  vim.wait(100, function()
    return false
  end, 10)
  assert(not called, "cancelled discovery must not invoke its callback")
  local called_again = false
  require("prompt.connectors").get("claude").discover("commands", { root = root }, function(items)
    called_again = #items > 0
  end)
  wait_for(function()
    return called_again
  end)
end

function M.test_normalization_preserves_nested_metadata_and_source_ownership()
  local item = {
    label = "nested",
    kind = "command",
    source_path = "/tmp/nested.md",
    documentation = { kind = "markdown", value = "text" },
    metadata = { provider = "test" },
  }
  local normalized = require("prompt.connectors.util").normalize_items({ item })[1]
  assert(item.path == nil, "normalization must not mutate connector-owned input")
  assert(normalized.path == item.source_path and normalized.source_path == item.source_path)
  assert(normalized.documentation.value == "text" and normalized.metadata.provider == "test")
end

function M.test_normalization_rejects_malformed_items()
  local items = require("prompt.connectors.util").normalize_items({
    { label = "valid", kind = "command" },
    { label = "missing-kind" },
    true,
  })
  assert(#items == 1 and items[1].label == "valid", "malformed connector items must be rejected")
end

return M
