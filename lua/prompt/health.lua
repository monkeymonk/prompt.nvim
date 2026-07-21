local M = {}

-- #21: classify an installed connector's version against its declared
-- `tested_versions` range. Returns one of "tested", "newer", "older",
-- "unknown" (version unparseable or no range recorded).
local function parse_semver(v)
  if type(v) ~= "string" then
    return nil
  end
  local maj, min, patch = v:match("(%d+)%.(%d+)%.(%d+)")
  if not maj then
    return nil
  end
  return { tonumber(maj), tonumber(min), tonumber(patch) }
end

local function cmp_semver(a, b)
  for i = 1, 3 do
    if a[i] ~= b[i] then
      return a[i] < b[i] and -1 or 1
    end
  end
  return 0
end

local function classify_version(version_str, tested)
  local v = parse_semver(version_str)
  if not v then
    return "unknown"
  end
  if not tested or (tested.min == nil and tested.max == nil) then
    return "unknown"
  end
  if tested.min then
    local vmin = parse_semver(tested.min)
    if vmin and cmp_semver(v, vmin) < 0 then
      return "older"
    end
  end
  if tested.max then
    local vmax = parse_semver(tested.max)
    if vmax and cmp_semver(v, vmax) > 0 then
      return "newer"
    end
  end
  return "tested"
end

-- Best-effort: run `argv` and return its first semver-looking token from
-- stdout, or nil if the command failed / produced nothing parseable.
local function run_version_command(argv)
  local ok, result = pcall(function()
    return vim.system(argv, { text = true, timeout = 2000 }):wait()
  end)
  if not ok or not result or result.code ~= 0 then
    return nil
  end
  return (result.stdout or ""):match("(%d+%.%d+%.%d+)")
end

function M.check()
  vim.health.start("prompt.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10+")
  else
    vim.health.error("Neovim 0.10+ required")
  end

  if vim.fn.executable("prompt-nvim") == 1 then
    vim.health.ok("prompt-nvim executable found")
  else
    vim.health.warn(
      "prompt-nvim executable not found on PATH",
      { "Install bin/prompt-nvim into your PATH" }
    )
  end

  local has_so = #vim.api.nvim_get_runtime_file("parser/markdown.so", true) > 0
  local has_dll = #vim.api.nvim_get_runtime_file("parser/markdown.dll", true) > 0
  if has_so or has_dll then
    vim.health.ok("markdown Treesitter parser found")
  else
    vim.health.warn("markdown Treesitter parser not found")
  end

  -- #25: warn (never auto-disable) when the installed launcher and the
  -- loaded plugin disagree about their version — this usually means the
  -- plugin was updated but `bin/prompt-nvim` wasn't reinstalled, or vice
  -- versa.
  vim.health.start("Version")
  local ok_plugin_version, plugin_version = pcall(function()
    return require("prompt.version").version
  end)
  if ok_plugin_version and plugin_version then
    vim.health.ok("plugin version " .. plugin_version)
  else
    vim.health.warn(
      "could not determine plugin version (lua/prompt/version.lua missing or invalid)"
    )
    ok_plugin_version = false
  end

  if vim.fn.executable("prompt-nvim") == 1 then
    local launcher_version = run_version_command({ "prompt-nvim", "--version" })
    if not launcher_version then
      vim.health.info(
        "could not determine prompt-nvim launcher version (--version produced no parseable output)"
      )
    elseif ok_plugin_version then
      if launcher_version == plugin_version then
        vim.health.ok("launcher version " .. launcher_version .. " matches plugin")
      else
        vim.health.warn(
          string.format(
            "Launcher %s does not match plugin %s. Re-run the plugin build/install step.",
            launcher_version,
            plugin_version
          )
        )
      end
    end
  end

  vim.health.start("Targets")
  local targets = require("prompt.registry").list_targets()
  if #targets == 0 then
    vim.health.warn("No targets registered — call require('prompt').setup()")
  else
    for _, def in ipairs(targets) do
      vim.health.ok(def.display_name .. " (" .. def.name .. ")")
    end
  end

  -- #20/#21: per-connector executable presence, stability, and best-effort
  -- version compatibility. Warn-only — nothing here disables a connector.
  vim.health.start("Connectors")
  local connector_names = require("prompt.connectors").list()
  for _, name in ipairs(connector_names) do
    local c = require("prompt.connectors").get(name)
    local meta = (c and c.meta) or {}
    local stability = meta.stability or "unknown"
    local available = c and c.available and c.available()

    if not available then
      vim.health.info(
        name
          .. " executable not found ("
          .. stability
          .. "; completion still works from config dirs)"
      )
    else
      local label = name .. " executable found (" .. stability .. ")"
      if meta.version_command then
        local version = run_version_command(meta.version_command)
        if not version then
          vim.health.info(
            label
              .. " — version unknown (could not run/parse "
              .. meta.version_command[1]
              .. " --version)"
          )
        else
          local status = classify_version(version, meta.tested_versions)
          if status == "tested" then
            vim.health.ok(label .. " — version " .. version .. " (tested)")
          elseif status == "newer" then
            vim.health.warn(label .. " — version " .. version .. " (newer than tested range)")
          elseif status == "older" then
            vim.health.warn(label .. " — version " .. version .. " (older than tested range)")
          else
            vim.health.info(
              label
                .. " — version "
                .. version
                .. " (untested range — no tested_versions recorded)"
            )
          end
        end
      else
        vim.health.ok(label)
      end
    end
  end

  vim.health.start("Configuration")
  local env = vim.env.PROMPT_NVIM_TARGET
  if env and not require("prompt.bridge").in_bridge_mode() then
    vim.health.info("PROMPT_NVIM_TARGET set outside bridge mode: " .. env)
  else
    vim.health.ok("environment sane")
  end
end

return M
