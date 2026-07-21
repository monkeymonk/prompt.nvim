# prompt.nvim showcase tape (https://github.com/charmbracelet/vhs).
#
# Regenerate ../assets/demo.gif with:
#     cd demo && vhs demo.tape
#
# Requires: vhs, nvim (0.10+), and fd/rg/git for @ completion. vhs bundles
# JetBrains Mono, so no font install is needed. A throwaway $HOME is used so
# only the fixture project's own .claude commands appear.

Output "../assets/demo.gif"
Require nvim

Set Shell "bash"
Set FontSize 18
Set Width 1200
Set Height 640
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms

# --- off-camera setup ---
Hide
Type "cd project && clear"
Enter
Sleep 300ms
Type "HOME=$(mktemp -d) nvim -u ../init.lua"
Enter
Sleep 1500ms
Type ":PromptNew claude"
Enter
Sleep 800ms
Type "i"
Show

# --- @ : file completion ---
Type "Refactor the login flow in @src/au"
Sleep 500ms
Tab
Sleep 1200ms
Ctrl+N
Sleep 800ms
Ctrl+Y
Sleep 500ms
Type "."
Enter
Sleep 400ms

# --- / : command completion (line start) ---
Type "/rev"
Sleep 500ms
Tab
Sleep 1200ms
Ctrl+N
Sleep 800ms
Ctrl+Y
Enter
Sleep 400ms

# --- ! : shell mode, file-argument completion (line start) ---
Type "!git add src/"
Sleep 500ms
Tab
Sleep 1200ms
Ctrl+N
Sleep 500ms
Ctrl+N
Sleep 800ms
Ctrl+Y
Sleep 500ms

Escape
Sleep 2500ms
