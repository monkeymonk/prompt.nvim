# Architecture

## Session Model

Every prompt edit is an isolated **session**. The session object
(`vim.b[bufnr].prompt_session`) encodes the editing context and lifecycle:

```lua
{
  id = "<string>",              -- unique per edit session
  target = "codex",             -- AI tool target (claude, codex, etc.)
  launch_cwd = "/abs/path",     -- the tool's project dir when launched
  root = "/abs/path",           -- detected project root from launch_cwd
  bridge = true,                -- bridge behavior enabled
  remote = false,               -- true when opened in an existing server (--server)
  original_path = "/abs/file",  -- the prompt file path
  backup_path = "/tmp/.../backup" or nil,  -- raw-byte backup
  state = "attached",           -- state machine: attached|returning|cancelling|closed|failed
}
```

### Session Lifecycle

```
fresh launch
  ↓
attach buffer, create session, state="attached"
  ↓
  ├─→ user edits and saves (:wq)
  │   ↓ write succeeds
  │   set_state("returning")
  │   ↓ close buffer (or quitall)
  │   set_state("closed")
  │
  └─→ user cancels (:PromptCancel or :q! on bridge buffer)
      ↓ restore from backup (raw bytes, no buffer serialization)
      set_state("cancelling")
      ↓ close buffer (or quitall)
      set_state("closed")

server mode (RPC)
  ↓
launcher sends session metadata via RPC (register call)
  ↓
launcher blocks on --remote-wait
  ↓
editor attaches buffer via BufReadPost, creates session, state="attached"
  ↓
[same as above: editing, returning, or cancelling]
  ↓
close buffer only (bdelete, not quitall)
  ↓
launcher unblocks; server remains open
```

## Completion Request Lifecycle

A completion request is issued when the user types a trigger character (`@`,
`/`, `!`) or continues within a trigger scope. The request:

1. **Parse context** — extract trigger type, query, cursor position, and active
   sources for the target.
2. **Activate sources** — gather enabled sources for the trigger (files,
   directories, commands, shell, connectors).
3. **Spawn concurrent source calls** — each source receives `ctx` (context:
   bufnr, target, root, query, trigger, etc.) and a callback. Sources may
   return a cancel function if they own async work (file scans).
4. **Collect results** — as sources callback, accumulate items. Track
   in-flight requests per bufnr to discard late results from superseded
   requests.
5. **Per-source timeout** — if a source doesn't callback within
   `completion.source_timeout_ms` (default 750ms), treat it as returning `{}`.
6. **Staleness check** — before publishing results, verify:
   - Request not cancelled (user issued a newer request).
   - Buffer still valid and unchanged.
   - Cursor still within the query region.
7. **Normalize and rank** — validate items (required fields: label,
   insert_text, kind; optional: scope, source_path, documentation),
   drop+debug-log invalid, apply ranking heuristics.
8. **Callback to integrations** — return ranked items to blink.cmp, nvim-cmp,
   or native picker.

## File Discovery

File discovery returns tracked and untracked files, excluding ignored entries.

### Backend Order

1. **fd** (`fd --type f -0` + `--type d -0`) — fastest, null-delimited.
2. **rg** (`rg --files -0`) — fast, respects `.gitignore`, null-delimited.
3. **git** (`git ls-files -z --cached --others --exclude-standard`) — includes
   untracked files; apply `opts.ignore` post-filter.
4. **Lua walk** — fallback directory traversal; does NOT honor `.gitignore`
   (log a debug message if `respect_gitignore=true` but git unavailable).

### Discovery Contract

- **Input:** `root` (project dir), `opts` (config table: `include_hidden`,
  `respect_gitignore`, `ignore`, `max_depth`, `scan_timeout_ms`,
  `max_entries_scanned`, `follow_symlinks`).
- **Output:** `{ files = [...], directories = [...] }` (relative paths; dirs
  have no trailing slash).
- **In-flight dedup:** identical concurrent requests (same root, same opts)
  spawn one scan; callbacks fan out on completion.
- **Cache key:** includes root, include_hidden, respect_gitignore, ignore,
  max_depth, max_results, and backend name.
- **Safety:** scan timeouts at `opts.scan_timeout_ms`; fallback walk stops at
  `opts.max_entries_scanned` entries.

## Connectors

A **connector** discovers AI-tool-specific completions (commands, skills,
agents, prompts) by scanning the tool's project and user config directories.

### Connector Lifecycle

1. **Register** — connector module exports `meta` (name, stability, executable,
   version_command, tested_versions).
2. **Available check** — `:checkhealth prompt` and lazy discovery call
   `M.available()` to verify the tool is on PATH.
3. **Discover** — on completion, connector's `discover(ctx)` is called with
   context (target, root, query kind); returns a list of items.
4. **Normalize** — items are validated (required: label, insert_text, kind)
   and invalid entries dropped + debug-logged.
5. **Invalidate** — on `:PromptRefresh`, project-specific caches are cleared.

### Stability Levels

**Stable** (actively maintained, version ranges documented):
- Claude Code
- Codex CLI

**Experimental** (version-tentative; warn in `:checkhealth prompt`):
- Gemini CLI
- OpenCode
- Pi

Experimental connectors include version probing; users can file issues if a
new tool version breaks discovery.

### Version Probing

Each connector's metadata includes an optional `version_command` (e.g.
`["codex", "--version"]`). `:checkhealth prompt` runs the command and:

- Parses the version string.
- Compares to `tested_versions.min` and `.max`.
- Reports: "tested", "newer than tested", "older than tested", or "unknown".

No connectors are auto-disabled; warnings surface compatibility cues.

## Sources

A **source** completes a single trigger type (`@` files, `/` commands, `!`
shell).

### Source Interface

```lua
{
  enabled = function(ctx) -> bool,  -- optional; decide if this source applies
  complete = function(ctx, callback) -> cancel | nil
}
```

- `ctx` provides: bufnr, target, trigger, query, root, sources (parsed list),
  and other parsed context.
- `callback(items)` must be called exactly once with a list of items. Fire-once
  guards prevent accidental double-counting.
- Return value: idempotent cancel function (e.g. kills a vim.system process) or
  `nil`.

### Built-in Sources

- **files** — fuzzy file search via filesystem backend.
- **directories** — directory paths.
- **pathsource** — augments files with segment-path navigation (`@src/`).
- **shell** — shell command and argument completions.
- **connector_source** — meta-source that runs all available connectors
  (claude, codex, gemini, opencode, pi) and normalizes output.

## Integrations

An **integration** wires prompt completion to an external completion framework.

### Integration Interface

```lua
{
  new = function() -> source_spec  -- for cmp-style sources
  complete = function(ctx, callback) -> ...,
  close = function() -> ...
}
```

Integrations register themselves with the completion framework (blink.cmp,
nvim-cmp, or native). On trigger, they call `require("prompt.completion").complete(ctx,
callback)`.

### Built-in Integrations

- **blink.lua** — blink.cmp source module.
- **cmp.lua** — nvim-cmp source.
- **native.lua** — vim.fn.complete / vim.ui.select picker.

## Caching

Results are cached per completion context (root + discovery type + backend +
options hash). Cache TTL is configurable (default 30s). `:PromptRefresh`
clears all caches and invalidates project-scoped discovery.

## Logging

Debug-level logs use the `prompt.log` module. Set `:set log.level=debug` in
config to trace:

- Source callback timing and counts.
- Discovery backend selection and timeouts.
- Connector availability and version probing.
- Staleness checks and request cancellation.
