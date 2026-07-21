# Release Checklist

This document describes the release gates and process for prompt.nvim.

## Semantic Versioning

prompt.nvim follows [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 0.2.0)
- **MAJOR** bumped for incompatible API changes (e.g., `api_version` increment).
- **MINOR** bumped for new features (backward compatible).
- **PATCH** bumped for bug fixes (backward compatible).

Pre-1.0, MINOR may include breaking changes; `api_version` signals whether
extensions need updates.

## Semantic Change Categories

Use these categories in commit messages and changelog entries to clarify the
impact:

- **feat** — new feature (bump MINOR if backward compatible; MAJOR otherwise).
- **fix** — bug fix (bump PATCH).
- **refactor** — code restructuring, no behavior change (PATCH if user-facing
  integration points change; otherwise transparent).
- **docs** — documentation updates (no version bump).
- **test** — test additions/fixes (no version bump).
- **perf** — performance improvement (bump PATCH if it changes observable timing).
- **security** — security fix or hardening (bump PATCH or MINOR depending on
  severity).

## Release Gates

Before releasing, verify:

### Code Quality

- [ ] All tests pass (`tests/run.lua`)
- [ ] Lua passes stylua (`stylua --check lua/`)
- [ ] Lua passes luacheck (`luacheck lua/ --globals vim`)
- [ ] Shell passes shellcheck (`shellcheck bin/prompt-nvim`)
- [ ] Shell passes shfmt (`shfmt --diff bin/prompt-nvim`)

### Documentation

- [ ] README.md updated (features, config, new targets if any)
- [ ] CHANGELOG.md includes a section for the new version with all changes
- [ ] ARCHITECTURE.md updated if internal design changed
- [ ] CONTRIBUTING.md updated if dev setup/process changed
- [ ] SECURITY.md updated if vulnerability policy changed
- [ ] Version numbers in code match:
  - `bin/prompt-nvim` VERSION variable
  - `lua/prompt/version.lua` version field
  - Git tag and GitHub release

### Compatibility

- [ ] All built-in connectors report stable or experimental per spec
- [ ] `:checkhealth prompt` reports no errors
- [ ] Known compatibility issues documented in docs/COMPATIBILITY.md
- [ ] Tested version ranges are realistic (not invented)

### Integration

- [ ] Fresh-mode launcher works (create file, edit, return, cancel)
- [ ] Server-mode launcher works (--server flag, two concurrent sessions)
- [ ] Bridge keymaps functional (return_prompt, cancel_prompt)
- [ ] Completion engines work (blink.cmp, nvim-cmp, native)
- [ ] File discovery works (fd → rg → git → Lua walk)
- [ ] No regression in existing features

## Release Steps

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

## Hotfixes

For critical bugs in a released version:

1. Create a branch from the release tag: `git checkout -b hotfix/0.2.1 v0.2.0`
2. Fix the bug and update versions.
3. Follow the Release Steps (commit, tag, release, merge).

## Experimental to Stable Promotion

When an experimental connector becomes stable:

1. Update the `meta.stability` field in the connector module.
2. Add tested version ranges to `meta.tested_versions`.
3. Add an integration test to `tests/integration/`.
4. Update docs/COMPATIBILITY.md.
5. Mention the promotion in the CHANGELOG under "Connector Compatibility".

See [CONTRIBUTING.md](../CONTRIBUTING.md#connector-promotion) for full criteria.
