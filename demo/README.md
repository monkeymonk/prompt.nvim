# Demo recording

Sources for the showcase GIF in the README (`../assets/demo.gif`).

## Regenerate

Requires [`vhs`](https://github.com/charmbracelet/vhs), `nvim` (0.10+), and
`fd`/`rg`/`git` for `@` file completion.

```sh
cd demo
vhs demo.tape   # writes ../assets/demo.gif
```

## What's here

- `demo.tape` — the vhs script (typing + completion keystrokes, timings, theme).
- `init.lua` — a throwaway Neovim config that loads prompt.nvim from this
  checkout (no plugin manager) and maps `<Tab>` to the built-in completer, so
  the recording needs neither blink.cmp nor nvim-cmp.
- `project/` — a tiny fixture project the demo runs inside: a few source files
  for `@`, `.claude/commands/*` for `/`, and a `CLAUDE.md` root marker.

The tape launches nvim with a throwaway `HOME` (`HOME=$(mktemp -d)`) so only the
fixture's own `.claude` commands appear, not yours.
