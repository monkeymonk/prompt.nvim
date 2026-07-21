---
name: Bug report
about: Report a bug or unexpected behavior
title: ''
labels: bug
assignees: ''
---

## Description

Describe the bug concisely. What did you expect, and what happened instead?

## Steps to Reproduce

1. ...
2. ...
3. ...

## Environment

- **prompt.nvim version:** (run `:PromptInfo`, copy the "Plugin version" line)
- **Launcher version:** (run `prompt-nvim --version`)
- **Neovim version:** (run `nvim --version`)
- **AI CLI tool and version:** (e.g. `codex --version`)
- **Fresh process or existing server?** (fresh / --server)
- **Completion engine:** (blink.cmp / nvim-cmp / native)
- **Filesystem backend:** (fd / rg / git / Lua walk)
- **OS:** (Linux / macOS / Windows + WSL / other)

## :PromptInfo Output

Run `:PromptInfo` in the buffer and paste the full output here:

```
[paste output here]
```

## Logs

If available, set the log level in your config:

```lua
require("prompt").setup({
  log = { level = "debug" },
})
```

Then reproduce the issue and share relevant debug messages from `:messages`.

## Additional Context

Any other relevant details (config overrides, filesystem layout, recent updates,
etc.).
