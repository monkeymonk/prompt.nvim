#!/bin/sh
# PROMPT_NVIM_EXECUTABLE test double for launcher_spec.sh: drives a
# fresh-process nvim non-interactively (no user typing) via -c commands, since
# a real interactive session can't be scripted from a shell test.
#
# Reads two env vars set by the caller:
#   PROMPT_NVIM_TEST_INIT  - absolute path to tests/minimal_init.lua
#   PROMPT_NVIM_TEST_DRIVE - a Lua statement string, run after attach(0)
set -eu

: "${PROMPT_NVIM_TEST_INIT:?PROMPT_NVIM_TEST_INIT must be set}"
: "${PROMPT_NVIM_TEST_DRIVE:?PROMPT_NVIM_TEST_DRIVE must be set}"

exec nvim --headless -u "$PROMPT_NVIM_TEST_INIT" \
    -c 'lua require("prompt").setup({})' \
    -c 'lua require("prompt").attach(0)' \
    -c "lua $PROMPT_NVIM_TEST_DRIVE" \
    "$@"
