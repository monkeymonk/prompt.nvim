# prompt.nvim shell integration (bash/zsh).
# Source this file, or add:  eval "$(prompt-nvim --print-shell zsh)"
# Each function launches the AI tool with prompt-nvim as its external editor.

claude() {
  PROMPT_NVIM_TARGET=claude \
  VISUAL=prompt-nvim \
  EDITOR=prompt-nvim \
  command claude "$@"
}

codex() {
  PROMPT_NVIM_TARGET=codex \
  VISUAL=prompt-nvim \
  EDITOR=prompt-nvim \
  command codex "$@"
}

gemini() {
  PROMPT_NVIM_TARGET=gemini \
  VISUAL=prompt-nvim \
  EDITOR=prompt-nvim \
  command gemini "$@"
}

opencode() {
  PROMPT_NVIM_TARGET=opencode \
  VISUAL=prompt-nvim \
  EDITOR=prompt-nvim \
  command opencode "$@"
}

pi() {
  PROMPT_NVIM_TARGET=pi \
  VISUAL=prompt-nvim \
  EDITOR=prompt-nvim \
  command pi "$@"
}
