# prompt.nvim shell integration (fish).
# Source this file, or add:  prompt-nvim --print-shell fish | source
# Each function launches the AI tool with prompt-nvim as its external editor.

function claude
    env PROMPT_NVIM_TARGET=claude VISUAL=prompt-nvim EDITOR=prompt-nvim command claude $argv
end

function codex
    env PROMPT_NVIM_TARGET=codex VISUAL=prompt-nvim EDITOR=prompt-nvim command codex $argv
end

function gemini
    env PROMPT_NVIM_TARGET=gemini VISUAL=prompt-nvim EDITOR=prompt-nvim command gemini $argv
end

function opencode
    env PROMPT_NVIM_TARGET=opencode VISUAL=prompt-nvim EDITOR=prompt-nvim command opencode $argv
end

function pi
    env PROMPT_NVIM_TARGET=pi VISUAL=prompt-nvim EDITOR=prompt-nvim command pi $argv
end
