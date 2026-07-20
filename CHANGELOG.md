# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-20

Initial release.

### Added

- External-editor bridge and the `prompt-nvim` launcher, so terminal AI
  coding tools can open their prompt in Neovim as `$VISUAL`/`$EDITOR`.
  Return on save; restore the original on cancel.
- Target registry with 5 builtin targets: Claude Code, Codex CLI, Gemini
  CLI, OpenCode, and Pi. Codex shares Claude Code's `@`/`/`/`!` bindings.
- `@` file/directory completion: repo-wide fuzzy find (`fd`/`rg`/`git`/Lua
  walk) plus segment path navigation (`@src/`, `@../`, `@/abs`, `@~/`).
- `/` completion for commands, skills, agents, and prompt templates,
  discovered per target from project and user config and tagged by scope.
- `!` shell mode: first word completes `$PATH` executables, argument words
  complete file/directory paths.
- Completion integrations: blink.cmp, nvim-cmp, and a framework-free native
  fallback (`vim.fn.complete` / `vim.ui.select`).
- Reference highlighting for `@`, `/`, `!` tokens.
- Statusline helpers.
- Health checks (`:checkhealth prompt`), Vim help (`:help prompt.nvim`),
  and a dependency-free test suite.
