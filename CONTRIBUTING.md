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
- Gemini, OpenCode, Pi: experimental until a maintainer volunteers; version
  probing remains in place to help users identify compatibility issues.

## Git Workflow

- Main branch: `main` — always deployable.
- Feature/fix branches: `feature/...` or `fix/...`.
- Commit messages: start with the semantic type (feat, fix, docs, test, refactor)
  and keep the first line under 70 characters.
- Pull request titles: concise; full context in the body.

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
