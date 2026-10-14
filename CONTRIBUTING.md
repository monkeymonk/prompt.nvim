# Contributing to prompt.nvim

## Development Setup

Clone the repo and symlink the launcher:

```sh
git clone https://github.com/monkeymonk/prompt.nvim ~/.config/nvim/prompt.nvim
cd ~/.config/nvim/prompt.nvim
ln -s "$(pwd)/bin/prompt-nvim" ~/.local/bin/prompt-nvim
```

Add to your Neovim config:

```lua
vim.opt.runtimepath:prepend(vim.fn.stdpath("config") .. "/prompt.nvim")
require("prompt").setup({})
```

Run `:checkhealth prompt` to verify the setup.

## Running Tests

The headless test suite uses a minimal Neovim init:

```sh
tests/run.lua
```

Or via shell with direct `nvim` invocation (requires Neovim 0.10+):

```sh
nvim --headless -u tests/minimal_init.lua -c 'lua require("tests.run").run()'
```

## Code Quality

### Lua

**Style (stylua):**

```sh
stylua --check lua/
```

Auto-fix:

```sh
stylua lua/
```

**Lint (luacheck):**

```sh
luacheck lua/ --globals vim
```

### Shell (bin/prompt-nvim)

**Lint (shellcheck):**

```sh
shellcheck bin/prompt-nvim
```

**Format (shfmt):**

```sh
shfmt --diff bin/prompt-nvim
```

Auto-fix:

```sh
shfmt -i 4 -w bin/prompt-nvim
```

## Plan → Build → Review

Substantial changes follow a three-stage review process:

1. **PLAN** — A reviewer decomposes the change into atomic, fully-specified tasks
   (files, exact changes, interfaces, edge cases). Zero unknowns pass forward.
2. **BUILD** — An implementer executes the plan exactly as specified. No scope
   expansion, no improvisation. If the plan is wrong, the task blocks and returns
   to PLAN.
3. **REVIEW** — The original reviewer audits the implementation for correctness,
   drift, and completeness. If changes are needed, the task loops back to PLAN.

Mechanical changes (one-liners, simple renames, config tweaks) may skip this
loop; feature additions and bug fixes use it.

## Adding a Connector

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
4. Add tests and update the Compatibility section in [README.md](README.md)
   once stable.

See "Connector Promotion" below for experimental -> stable criteria.

## Connector Promotion: Experimental → Stable

A connector moves from experimental to stable when it meets these criteria:

1. **Documented version range** — `tested_versions` in connector metadata set to
   a realistic min/max (not a single version or invention).
2. **Integration fixture** — A test case covering the connector's discovery
   (commands, skills, agents) against a real project config layout.
3. **Integration test** — A `tests/integration/` test exercising the full
   completion flow through the connector (trigger, query, result ranking).
4. **Health check pass** — `:checkhealth prompt` reports the connector as
   "stable" with tested versions.

Examples:

- Claude Code: 2025-01+ (active maintenance; documented version range).
- Codex: latest release (maintained in parallel; tested against recent version).
- Gemini, OpenCode, Pi, OMP: experimental until a maintainer volunteers; version
  probing remains in place to help users identify compatibility issues.

When promoting, also update the stable/experimental lists in README.md's
Compatibility section and mention the promotion in CHANGELOG.md.

## Git Workflow

- Main branch: `main` — always deployable.
- Feature/fix branches: `feature/...` or `fix/...`.
- Commit messages: start with the semantic type (feat, fix, docs, test, refactor)
  and keep the first line under 70 characters.
- Pull request titles: concise; full context in the body.

## Release Process

prompt.nvim follows [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 0.2.0)
- **MAJOR** bumped for incompatible API changes (e.g., `api_version` increment).
- **MINOR** bumped for new features (backward compatible).
- **PATCH** bumped for bug fixes (backward compatible).

Pre-1.0, MINOR may include breaking changes; `api_version` signals whether
extensions need updates.

Use these categories in commit messages and changelog entries:

- **feat** — new feature (bump MINOR if backward compatible; MAJOR otherwise).
- **fix** — bug fix (bump PATCH).
- **refactor** — code restructuring, no behavior change (PATCH if user-facing
  integration points change; otherwise transparent).
- **docs** — documentation updates (no version bump).
- **test** — test additions/fixes (no version bump).
- **perf** — performance improvement (bump PATCH if it changes observable timing).
- **security** — security fix or hardening (bump PATCH or MINOR depending on
  severity).

### Release Gates

Before releasing, verify:

**Code Quality** — all tests pass (`tests/run.lua`); Lua/shell lint and
format pass (see Code Quality above).

**Documentation**:
- [ ] README.md updated (features, config, new targets if any)
- [ ] CHANGELOG.md includes a section for the new version with all changes
- [ ] ARCHITECTURE.md updated if internal design changed
- [ ] CONTRIBUTING.md updated if dev setup/process changed
- [ ] SECURITY.md updated if vulnerability policy changed
- [ ] Version numbers in code match: `bin/prompt-nvim` VERSION variable,
      `lua/prompt/version.lua` version field, git tag, and GitHub release

**Compatibility**:
- [ ] All built-in connectors report stable or experimental per spec
- [ ] `:checkhealth prompt` reports no errors
- [ ] Known compatibility issues documented in README.md's Compatibility
      section
- [ ] Tested version ranges are realistic (not invented)

**Integration**:
- [ ] Fresh-mode launcher works (create file, edit, return, cancel)
- [ ] Server-mode launcher works (--server flag, two concurrent sessions)
- [ ] Bridge keymaps functional (return_prompt, cancel_prompt)
- [ ] Completion engines work (blink.cmp, nvim-cmp, native)
- [ ] File discovery works (fd → rg → git → Lua walk)
- [ ] No regression in existing features

### Release Steps

1. **Create a release branch** (e.g., `release/0.2.0`).

2. **Update versions:**
   ```sh
   # bin/prompt-nvim
   VERSION="0.2.0"

   # lua/prompt/version.lua
   return { version = "0.2.0" }
   ```

3. **Prepare CHANGELOG:**
   - Date the unreleased section: `## [0.2.0] - 2026-07-20`
   - Review entries against the commit history.

4. **Run full validation:**
   ```sh
   tests/run.lua
   stylua --check lua/
   luacheck lua/ --globals vim
   shellcheck bin/prompt-nvim
   nvim -c ':checkhealth prompt' -c ':q'
   ```

5. **Commit and tag:**
   ```sh
   git add -A
   git commit -m "chore: bump version to 0.2.0"
   git tag -a v0.2.0 -m "Release 0.2.0: [summary]"
   ```

6. **Push:**
   ```sh
   git push origin release/0.2.0
   git push origin v0.2.0
   ```

7. **Create GitHub release:**
   - Go to [Releases](https://github.com/monkeymonk/prompt.nvim/releases).
   - Draft a new release from the git tag.
   - Copy the CHANGELOG section for this version into the release notes.
   - Publish.

8. **Merge back to main:**
   ```sh
   git checkout main && git pull
   git merge release/0.2.0
   git push origin main
   ```

### Hotfixes

For critical bugs in a released version:

1. Create a branch from the release tag: `git checkout -b hotfix/0.2.1 v0.2.0`
2. Fix the bug and update versions.
3. Follow the Release Steps (commit, tag, release, merge).

## Running the Plugin in Development

To test the launcher fresh-mode flow:

```sh
cd /tmp && echo "Hello, world" > test.md
PROMPT_NVIM_TARGET=claude ~/.local/bin/prompt-nvim test.md
# Edit in Neovim, then :wq to return or :PromptCancel to restore
```

To test server mode:

```sh
# Terminal 1: start a server
nvim --headless --listen /tmp/nvim-server.sock

# Terminal 2: open a prompt in that server
PROMPT_NVIM_TARGET=codex ~/.local/bin/prompt-nvim --server /tmp/nvim-server.sock test.md
```

## Security Policy

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities and supported
versions.
