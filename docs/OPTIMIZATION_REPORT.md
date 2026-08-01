# prompt.nvim Optimization Report

Status: implementation plan

This report records the optimization analysis for prompt.nvim and is the
reference for the implementation round. The implementation must preserve all
currently working completion, connector, bridge, remote-session, cancellation,
and byte-fidelity behavior.

## Scope

The review covered:

- `lua/prompt/**/*.lua`
- `plugin/prompt.lua`
- unit and integration tests
- `ARCHITECTURE.md`
- cache, completion, source, connector, and lifecycle behavior

The plugin currently contains approximately 4,061 lines of Lua. Connector
modules account for approximately 1,012 lines and completion sources for
approximately 512 lines.

## Baseline validation

At analysis time:

- Unit suite: 38 passed, 0 failed.
- Install smoke tests: 2 passed, 0 failed.
- Launcher integration tests: 15 passed, 0 failed.
- Backend parity tests passed as part of the unit suite.
- Full integration suite: the server test failed because its Unix RPC socket
  never appeared in the execution environment. This was an environment-level
  failure and was not reproduced as a plugin assertion failure.
- No source files were changed before this report.

## Current behavior that is contractual

The implementation must continue to guarantee:

1. Completion works from configured skill, agent, command, and prompt
   directories even when the external executable is not installed. The health
   output explicitly documents this behavior.
2. Each source invokes its callback at most once.
3. A completion request superseded by a newer request cannot publish results.
4. Source timeouts still complete the aggregate request.
5. Source-owned asynchronous work can be cancelled.
6. Cancelled or timed-out scans do not populate the cache with partial data.
7. Completion callbacks are not invoked from an unsafe libuv fast-event
   context when Neovim API calls are required.
8. Connector output fields, including `path`, `source_path`, documentation,
   metadata, scope, labels, and kinds, retain their current meaning.
9. Bridge and remote session lifecycle behavior is unchanged, including raw
   byte restoration on cancellation and force-quit.
10. Public registration APIs and connector interfaces remain compatible.

## Findings and actions

### 1. Connector discovery can block the editor

Connector sources call discovery synchronously from completion:

- `lua/prompt/sources/connector_source.lua`
- `lua/prompt/connectors/util.lua`

The scanners use synchronous directory iteration and file reads. The cache
reduces repeated work, but the first completion after expiry can scan project
and user directories while the completion request is running.

#### Action

Make connector scanning non-blocking while preserving the existing source
contract. The scanner must return an idempotent cancellation function and call
its callback exactly once.

The first implementation should use bounded scheduled chunks of directory and
metadata work. Do not add a dependency or worker abstraction. Only introduce
fully asynchronous libuv file reads if profiling shows scheduled chunks are
insufficient.

Required behavior:

- project and user roots are scanned identically to today;
- results have identical ordering unless ordering is explicitly unspecified;
- cancellation stops future work;
- timeout and stale-request handling remain owned by the existing completion
  coordinator;
- partial or cancelled results are never cached;
- nonexistent directories still complete with an empty result.

### 2. Connector availability must not gate discovery

Every connector exposes `available()`, but it is currently used for health
reporting rather than completion gating. This is intentional: configured files
must remain completable without the executable.

#### Action

Do not add an executable-availability gate. Do not change the documented
behavior to trade a small filesystem optimization for a compatibility break.

If the implementation needs an optimization here, it may memoize availability
for health reporting only, but that is optional and low priority.

### 3. Cache invalidation is unnecessarily broad

The markdown write autocmd currently clears all caches. A single `SKILL.md` or
agent-file write can therefore invalidate filesystem, directory, shell, root,
and unrelated connector results.

#### Action

Add a generic namespace/prefix invalidation primitive to `prompt.cache`, such as
`invalidate_prefix("conn:")`. Use it for connector-related markdown writes.

Keep `PromptRefresh` as the explicit full-cache reset. Existing project
invalidation behavior must remain available for filesystem and connector code.

Required tests:

- connector entries are removed;
- filesystem entries survive connector invalidation;
- shell entries survive connector invalidation;
- full refresh still removes all entries.

### 4. Connector modules duplicate the same lifecycle

The Claude, Codex, Gemini, OpenCode, and Pi connectors repeat cache lookup,
root construction, kind dispatch, callback handling, and invalidation. Their
real differences are provider-specific metadata and directory specifications.

#### Action

Create one internal connector factory or discovery definition module. Keep the
public connector shape unchanged:

```lua
{
  name = ...,
  meta = ...,
  available = function() ... end,
  discover = function(kind, ctx, callback) ... end,
  invalidate = function(root) ... end,
}
```

Each provider module should contain only provider-specific data and behavior:

- executable and metadata;
- project directory;
- user directory resolver;
- kind-to-scanner mapping;
- provider-specific environment handling.

The generic factory owns:

- cache-key construction;
- root collection;
- scanner dispatch;
- callback-once protection;
- cancellation;
- connector-cache invalidation.

Do not centralize all provider paths in an unrelated global table. The
provider module remains the single source of truth for its paths.

### 5. Connector cache keys omit resolved user roots

Current connector keys contain connector, kind, and project root, but not all
resolved user/configuration roots. This can produce stale results if relevant
environment configuration changes during a session.

#### Action

The factory must construct deterministic keys from:

- connector name;
- completion kind;
- project root;
- resolved user roots;
- relevant environment-derived configuration paths.

Do not serialize the entire configuration object. Include only values that
change the scan result.

Required tests:

- project-root separation;
- kind separation;
- OpenCode configuration-directory separation;
- Pi multi-root separation;
- cache reuse when all scan inputs are identical.

### 6. Connector candidates are normalized more than once

Connector output is validated/deep-copied by `connectors.util`, then copied
again by the general candidate normalizer.

#### Action

Reduce avoidable allocation while preserving validation and source ownership.
The implementation may use one fresh normalized representation, but must not
mutate connector-owned input tables.

Preserve:

- `source_path` and `path` compatibility;
- nested documentation and metadata;
- optional fields;
- malformed-item rejection;
- generic file and shell candidate behavior.

Do not remove validation merely to reduce allocations.

### 7. Loaded-buffer indexing is a possible hot-path optimization

`prompt.completion` rebuilds the open-buffer map for each completion request.
This is an O(number of loaded buffers) operation on every keystroke.

#### Action

Measure this before changing it. If it is material with realistic buffer
counts, maintain a per-root index updated by buffer add, rename, delete, and
unload events. Otherwise leave the current simple implementation in place.

This optimization must not alter open-buffer ranking behavior.

## Implementation phases

### Phase A: safety baseline and focused fixtures

- Add or extend fixtures for multiple connector roots and user roots.
- Add tests for connector results when executables are unavailable.
- Add cache namespace tests.
- Preserve and run the existing race, integration, and backend parity tests.

No production behavior should change in this phase.

### Phase B: targeted cache invalidation

- Add cache namespace/prefix invalidation.
- Change markdown write invalidation to connector-only invalidation.
- Retain full invalidation for `PromptRefresh`.
- Run focused cache and integration tests.

### Phase C: connector definition factory

- Implement the internal generic factory.
- Convert one connector first, preferably Claude.
- Compare its output against the old implementation using existing fixtures.
- Convert the remaining connectors one at a time.
- Remove only duplication made obsolete by the factory.
- Run connector parity tests after every conversion.

### Phase D: cache-key correction

- Add all scan-result inputs to the generic connector cache key.
- Add environment-path test coverage.
- Confirm existing cache reuse and invalidation behavior.

### Phase E: non-blocking discovery

- Add bounded scheduled scanning.
- Return cancellation functions from scanners.
- Ensure connector source cancellation reaches the scanner.
- Test callback-once, cancellation, timeout, stale results, and cache safety.
- Profile before and after using realistic project and user directories.

### Phase F: normalization allocation reduction

- Consolidate or simplify connector candidate normalization.
- Verify source immutability and field compatibility.
- Run malformed-item and metadata-preservation tests.

### Phase G: optional loaded-buffer optimization

- Measure the current map-building cost.
- Implement an index only if the measurement justifies its added lifecycle
  complexity.
- Add buffer lifecycle tests if implemented.

## Verification gate

Before considering the implementation complete:

- all existing unit tests pass;
- all new cache tests pass;
- all connector parity tests pass;
- async callback and cancellation tests pass;
- malformed-item tests pass;
- launcher and install smoke tests pass;
- full integration tests pass in an environment supporting the server socket;
- no executable-availability behavior has changed;
- no bridge, remote, lifecycle, or byte-restoration behavior has changed;
- no new dependency was introduced;
- no unrelated files were reformatted or refactored;
- the final diff contains no TODOs, placeholders, or pseudocode.

## Explicit non-goals

- Do not gate connector completion on executable availability.
- Do not redesign the completion request lifecycle.
- Do not replace the filesystem backend strategy.
- Do not merge bridge/session logic into completion code.
- Do not add a plugin-wide event bus.
- Do not add configuration options unless a compatibility-preserving need is
  demonstrated by tests or profiling.
- Do not optimize ranking or trigger parsing without measurements showing that
  they are material costs.
- Do not change candidate ordering unless existing behavior is proven
  accidental and tests are updated deliberately.
