# Security Policy

## Shell Execution

The `!` shell completion source does **NOT** execute the typed text. It:

- Parses the line to identify the command name and current argument using a
  lexer (shell syntax aware: quotes, escapes, operators).
- Verifies that the command name is executable on `PATH` by checking the file
  mode's executable bit.
- Completes arguments as file/directory paths.

The typed shell line is never passed to a shell interpreter. Completion happens
in the editor; only the finished prompt is returned to the AI tool.

## Reporting a Vulnerability

Please report security issues via the GitHub Security Advisory mechanism:

1. Go to the [prompt.nvim Security Advisory page](https://github.com/monkeymonk/prompt.nvim/security/advisories).
2. Click "Report a vulnerability" and fill in the details.
3. Do not open a public issue.

Or email security concerns privately to the maintainer. We will acknowledge your
report within 48 hours and provide a timeline for a fix.

## Supported Versions

Security updates are provided for:

- **Latest release (0.2.0+)** — active maintenance.
- **Previous release (0.1.x)** — critical fixes only (time-permitting).

Older releases receive no security updates. Users are encouraged to upgrade to
the latest version.

## Third-Party Dependencies

prompt.nvim requires:

- **Neovim 0.10+** (no external Lua dependencies; ships with Lua 5.1 / LuaJIT).
- **Optional tools** on PATH for performance (`fd`, `rg`, `git`, shell).

Neovim is independently maintained; users should update Neovim via their distro
or official channels.

## Local File Access

The plugin reads and writes only:

- The current prompt file (via external-editor callback from the AI tool).
- Project/user config directories (e.g. `~/.claude`, `~/.codex`, `~/.gemini`).
- Temporary backup files during the editing session (cleaned up automatically).

File discovery respects `.gitignore` and the `ignore` config option. Write
operations require explicit user action (`:wq` to save, `:PromptCancel` to
restore).
