# prompt.nvim shell integration (nushell).
# Add to your config, or:  prompt-nvim --print-shell nu | save -f ~/.config/nushell/prompt-nvim.nu
# Shape targets nushell 0.90+; older/newer versions may need adjustment.
# Each command launches the AI tool with prompt-nvim as its external editor.

def --wrapped claude [...args] {
    with-env {PROMPT_NVIM_TARGET: claude, VISUAL: prompt-nvim, EDITOR: prompt-nvim} {
        ^claude ...$args
    }
}

def --wrapped codex [...args] {
    with-env {PROMPT_NVIM_TARGET: codex, VISUAL: prompt-nvim, EDITOR: prompt-nvim} {
        ^codex ...$args
    }
}

def --wrapped gemini [...args] {
    with-env {PROMPT_NVIM_TARGET: gemini, VISUAL: prompt-nvim, EDITOR: prompt-nvim} {
        ^gemini ...$args
    }
}

def --wrapped opencode [...args] {
    with-env {PROMPT_NVIM_TARGET: opencode, VISUAL: prompt-nvim, EDITOR: prompt-nvim} {
        ^opencode ...$args
    }
}

def --wrapped pi [...args] {
    with-env {PROMPT_NVIM_TARGET: pi, VISUAL: prompt-nvim, EDITOR: prompt-nvim} {
        ^pi ...$args
    }
}
