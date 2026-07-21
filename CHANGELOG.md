# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.2] - 2026-07-21

### Docs

- Add a showcase GIF (`@` file, `/` command, and `!` shell completion) to the
  README.
- Add reproducible in-repo demo recording sources under `demo/` — a vhs tape, an
  isolated Neovim config that loads the plugin from the checkout, and a small
  fixture project — so the GIF can be regenerated with `cd demo && vhs demo.tape`.

## [0.2.1] - 2026-07-21

### Fixed

- `@` completion crashed on first use with `E5560: nvim_buf_is_valid must not be
  called in a fast event context`. The completion aggregator's `finish()` ran
  its staleness check (and normalize/rank) synchronously, but a filesystem
  source calls back from `vim.system`'s `on_exit` (a libuv fast-event context)
  where `nvim_*` calls are forbidden. `finish()` now defers all of that work via
  `vim.schedule`. Regression test added for a source that calls back from a raw
  fast-event context.

## [0.2.0] - 2026-07-21

### Bridge Correctness

- Session object (`vim.b[bufnr].prompt_session`) replaces ad-hoc buffer vars,
  tracking session id, target, root, launch cwd, bridge/remote mode, and a
  lifecycle state machine (`attached → returning/cancelling → closed`).
- Byte-preserving cancel: raw file backup restore preserves CRLF, BOM, and
  no-final-newline through cancellation without buffer serialization.
- Quit semantics: a saved quit (`:wq`/`:x`/`ZZ`) returns the edited prompt; a
  force-quit with unsaved edits (`:q!`/`:qa!`) restores the original
  byte-for-byte. (Previously the lifecycle guard cancelled on any quit,
  discarding saved edits.)
- Server-mode RPC: open prompts in an existing Neovim server via
  `--server <socket>`. Because Neovim does not implement `--remote-wait`, the
  launcher registers session metadata over RPC, opens the prompt, and polls
  until it closes — so the server stays alive and two prompts from different
  projects run concurrently with independent session state, closing only their
  own buffer. (0.1.0's `--server` relied on `--remote-wait` and never worked.)
- Crash safety: on abnormal exit (status > 128), the fresh-mode launcher
  restores the original file from the raw backup.

### Deterministic Completion

- Request-based completion tracking: newer requests supersede older ones.
  Sources that call back late are discarded; cancelled requests abort in-flight
  file scans.
- Per-source timeout (`completion.source_timeout_ms`, default 750ms): a silent
  source does not block aggregate completion.
- Fire-once callback guards prevent double-counting from sources that call back
  multiple times.

### File Discovery

- Canonical contract: backends return tracked and untracked files (including
  `.gitignore`-ignored entries if `respect_gitignore=false`), minus `ignore`
  patterns.
- Backend parity: fd, rg, git, and pure-Lua walk all implement the same logic.
  Pure-Lua fallback does not honor `.gitignore` (use `fd`/`rg`/`git` when
  gitignore respect is required).
- Safety limits: `scan_timeout_ms` (default 1000ms) limits all backends;
  fallback walk honors `max_entries_scanned` (default 100000) and max_depth.
- In-flight dedup: identical concurrent requests spawn one scan; callbacks fan
  out on completion.

### Shell Completion

- Real lexer (`shell_lex.lua`) parses shell syntax: single/double quotes,
  backslash escapes, operators (`|`, `&&`, `;`), VAR=value assignments,
  --opt=value patterns, and redirections.
- Executable check: command completions verify executable bit (mode & 0111),
  filtering out directories and non-executables on PATH.
- Correct argument/path routing: commands vs paths determined by lexer context
  (is_command_position), not naive word position.

### Connector Compatibility

- Stable vs experimental labeling: Claude Code and Codex are stable; Gemini,
  OpenCode, and Pi are experimental and warn in `:checkhealth prompt`.
- Version probing per connector: tested version ranges reported; health checks
  warn if installed version is outside tested range.
- Item validation: connector output normalized centrally; malformed items dropped
  + debug-logged, not crashed on.

### Extension API

- `api_version` field exposed (`require("prompt").api_version = 1`), allowing
  extensions to detect breaking changes.
- Registry validation: `register_target`, `register_source`, `register_connector`
  validate at registration time (required fields, well-formed triggers, callable
  completions, unique names, valid kinds).

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
