# Connector Compatibility

This matrix documents the supported AI CLI tools, their stability in
prompt.nvim, and tested version ranges.

## Compatibility Matrix

| Tool | Stability | Tested Min | Tested Max | Status |
| --- | --- | --- | --- | --- |
| Claude Code | Stable | 2025-01 | current | Active maintenance |
| Codex CLI | Stable | 1.0.0 | latest | Maintained in parallel |
| Gemini CLI | Experimental | — | — | Version-tentative |
| OpenCode | Experimental | — | — | Version-tentative |
| Pi | Experimental | — | — | Version-tentative |

**Stable** connectors are actively maintained and verified against documented
version ranges.

**Experimental** connectors are version-tentative: discovery layouts may change
between tool versions. Users should file issues if a new version breaks
completion.

## Installation & Verification

### Claude Code

```sh
# Verify available
which claude

# Check version
claude --version

# Run health check
nvim -c ':checkhealth prompt'
```

Claude Code shares the `.claude` config directory with Codex CLI. See
[Usage](https://github.com/monkeymonk/prompt.nvim#targets) for discovery paths.

### Codex CLI

```sh
# Verify available
which codex

# Check version
codex --version
```

Codex shares Claude Code's `@`/`/`/`!` bindings. See
[Usage](https://github.com/monkeymonk/prompt.nvim#targets) for discovery paths
(`.codex/{skills,prompts}`).

### Gemini CLI

```sh
# Verify available
which gemini

# Check version (if supported)
gemini --version  # may not be available
```

Gemini discovery reads TOML files from `~/.gemini/{commands,skills,agents}`.
Connector is experimental; verify against your installed version.

### OpenCode

```sh
# Verify available
which opencode

# Config directory
$OPENCODE_CONFIG_DIR or ~/.config/opencode
```

OpenCode connector is experimental; discovery layout may change.

### Pi

```sh
# Verify available
which pi

# Config directory
~/.config/pi or ~/.pi
```

Pi connector is experimental; discovery layout may change.

## Health Checks

Run `:checkhealth prompt` to see:

- Available connectors (executable on PATH).
- Stability level (stable vs experimental).
- Installed version (if version_command is available).
- Compatibility status (tested / newer / older / unknown).

Example output:

```
prompt.nvim
============

Backend: nvim 0.11.0 on Linux
Launcher: prompt-nvim 0.2.0 (OK)
Plugin: 0.2.0 (OK)

Connectors:
  claude       stable    2025-01 (executable found, version probed)
  codex        stable    1.2.0 (executable found, version older than tested range)
  gemini       experimental (not found)
  opencode     experimental (executable found, version unknown)
  pi           experimental (not found)
```

## Troubleshooting

### Tool Not Found

Ensure the tool's executable is on your `PATH`:

```sh
which <tool>    # check availability
echo $PATH      # verify the directory containing the tool is listed
```

### Version Mismatch Warning

If `:checkhealth prompt` reports "older" or "newer" than tested:

- **Older:** A known issue may be fixed in a newer version; consider upgrading.
- **Newer:** Discovery layout may differ; file an issue with `:PromptInfo` output
  if completion doesn't work.

### No Completions for a Tool

1. Run `:checkhealth prompt` to verify the tool is found.
2. Ensure discovery directories exist (e.g. `~/.claude/commands/`).
3. Check `:PromptInfo` to see which sources are active.
4. Set `:set log.level=debug` and review completion logs for errors.

## Contributing a Connector

To add a new tool:

1. Create `lua/prompt/connectors/<tool>.lua` with:
   ```lua
   M.meta = {
     name = "<tool>",
     stability = "experimental",
     executable = "<tool-binary-name>",
     version_command = { "<tool-binary-name>", "--version" },
     tested_versions = { min = "x.y.z", max = "x.y.z" },  -- or nil
   }
   ```

2. Implement `M.discover(kind, ctx, callback)` to scan the tool's config.

3. Register in `lua/prompt/connectors/init.lua`.

4. Add tests and update this matrix once stable.

See [CONTRIBUTING.md](../CONTRIBUTING.md#connector-promotion) for promotion
criteria (experimental → stable).
