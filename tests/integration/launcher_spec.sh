#!/bin/sh
# Fresh-process launcher integration tests (WP-H): drives the real
# bin/prompt-nvim binary end to end, with PROMPT_NVIM_EXECUTABLE pointed at
# nvim_wrapper.sh so a headless nvim can be scripted non-interactively.
#
# Run directly: tests/integration/launcher_spec.sh
# Exit code: 0 if every test passed, 1 otherwise. Emits TAP-ish "ok"/"not ok"
# lines plus a final "N passed, M failed" summary, same shape as tests/run.lua.
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(CDPATH='' cd -- "$script_dir/../.." && pwd)
launcher="$root_dir/bin/prompt-nvim"
init="$root_dir/tests/minimal_init.lua"
wrapper="$script_dir/nvim_wrapper.sh"

pass_count=0
fail_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf 'ok - %s\n' "$1"
}

fail() {
    fail_count=$((fail_count + 1))
    printf 'not ok - %s: %s\n' "$1" "$2"
}

bytes_of() {
    od -An -tx1 -- "$1" 2>/dev/null | tr -d ' \n'
}

# run_fresh DRIVE_LUA FILE [TARGET] -> sets $run_fresh_status
run_fresh() {
    run_fresh_drive="$1"
    run_fresh_file="$2"
    run_fresh_target="${3:-claude}"
    PROMPT_NVIM_EXECUTABLE="$wrapper" \
        PROMPT_NVIM_TEST_INIT="$init" \
        PROMPT_NVIM_TEST_DRIVE="$run_fresh_drive" \
        timeout 20 "$launcher" --target "$run_fresh_target" -- "$run_fresh_file"
    run_fresh_status=$?
}

work_dir=$(mktemp -d)
# shellcheck disable=SC2329 # invoked indirectly via `trap ... EXIT INT TERM`
cleanup() {
    chmod -R u+rwx "$work_dir" 2>/dev/null || true
    rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

test_successful_return() {
    f="$work_dir/return.md"
    printf 'hello\n' >"$f"
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"edited"}); vim.cmd("PromptReturn")' "$f"
    got=$(cat "$f")
    if [ "$run_fresh_status" -eq 0 ] && [ "$got" = "edited" ]; then
        pass "successful return writes the edited content"
    else
        fail "successful return writes the edited content" "status=$run_fresh_status content=$got"
    fi
}

# cancel_case NAME FIXTURE_PRINTF_ARGS...
cancel_case() {
    name="$1"
    shift
    f="$work_dir/cancel-$name.md"
    # shellcheck disable=SC2059 # intentional: $1 supplies printf backslash escapes for each fixture
    printf "$@" >"$f"
    before=$(bytes_of "$f")
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"MUTATED","BY","TEST"}); vim.cmd("PromptCancel")' "$f"
    after=$(bytes_of "$f")
    if [ "$run_fresh_status" -eq 0 ] && [ "$before" = "$after" ]; then
        pass "cancel byte-restores: $name"
    else
        fail "cancel byte-restores: $name" "status=$run_fresh_status before=$before after=$after"
    fi
}

test_cancel_no_final_newline() { cancel_case "no-final-newline" 'no trailing newline here'; }
test_cancel_one_newline() { cancel_case "one-newline" 'a single line\n'; }
test_cancel_crlf() { cancel_case "crlf" 'line one\r\nline two\r\n'; }
test_cancel_bom() { cancel_case "utf8-bom" '\357\273\277hello\n'; }
test_cancel_empty() { cancel_case "empty" ''; }
test_cancel_unicode() { cancel_case "unicode" 'h\303\251llo \360\237\216\211\n'; }
test_cancel_trailing_blanks() { cancel_case "trailing-blanks" 'a\n\n\n'; }

test_missing_file() {
    f="$work_dir/does-not-exist.md"
    rm -f "$f"
    run_fresh 'vim.cmd("PromptCancel")' "$f"
    if [ "$run_fresh_status" -eq 0 ] && [ ! -f "$f" ]; then
        pass "missing file: cancel on a nonexistent file does not create it"
    else
        fail "missing file: cancel on a nonexistent file does not create it" "status=$run_fresh_status exists=$([ -f "$f" ] && echo yes || echo no)"
    fi
}

test_unknown_target() {
    f="$work_dir/unknown-target.md"
    printf 'original\n' >"$f"
    before=$(bytes_of "$f")
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"MUTATED"}); vim.cmd("PromptCancel")' "$f" "this-target-does-not-exist"
    after=$(bytes_of "$f")
    if [ "$run_fresh_status" -eq 0 ] && [ "$before" = "$after" ]; then
        pass "unknown target does not crash the launcher"
    else
        fail "unknown target does not crash the launcher" "status=$run_fresh_status before=$before after=$after"
    fi
}

test_spaces_in_filename() {
    f="$work_dir/my prompt with spaces.md"
    printf 'hi\n' >"$f"
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"edited spaced"}); vim.cmd("PromptReturn")' "$f"
    got=$(cat "$f")
    if [ "$run_fresh_status" -eq 0 ] && [ "$got" = "edited spaced" ]; then
        pass "filenames with spaces work end to end"
    else
        fail "filenames with spaces work end to end" "status=$run_fresh_status content=$got"
    fi
}

test_simulated_crash_restores_backup() {
    f="$work_dir/crash.md"
    printf 'before crash\n' >"$f"
    before=$(bytes_of "$f")
    # `:cquit N` exits with status N directly (no signal needed): the
    # launcher's crash-safety net triggers on any status > 128, exactly like a
    # process killed by a signal would report.
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"MUTATED-BEFORE-CRASH"}); vim.cmd("cquit 137")' "$f"
    after=$(bytes_of "$f")
    if [ "$run_fresh_status" -eq 137 ] && [ "$before" = "$after" ]; then
        pass "simulated crash (status>128) restores the raw backup"
    else
        fail "simulated crash (status>128) restores the raw backup" "status=$run_fresh_status before=$before after=$after"
    fi
}

test_write_permission_failure() {
    sub_dir="$work_dir/readonly-dir"
    mkdir -p "$sub_dir"
    f="$sub_dir/prompt.md"
    printf 'original\n' >"$f"
    before=$(bytes_of "$f")
    chmod 0444 "$f"
    chmod 0555 "$sub_dir"
    # PromptReturn's write fails (no permission); the plugin state-guards and
    # deliberately does NOT close on a failed write, so the driver script
    # forces the process to exit right after so the test doesn't hang.
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"SHOULD-NOT-BE-WRITTEN"}); vim.cmd("PromptReturn"); vim.cmd("cquit 1")' "$f"
    chmod 0755 "$sub_dir"
    chmod 0644 "$f"
    after=$(bytes_of "$f")
    if [ "$run_fresh_status" -ne 0 ] && [ "$before" = "$after" ]; then
        pass "write-permission failure surfaces without data loss"
    else
        fail "write-permission failure surfaces without data loss" "status=$run_fresh_status before=$before after=$after"
    fi
}

# Bare-quit lifecycle (QuitPre/VimLeavePre), NOT the Prompt* commands: a saved
# quit must keep edits (return), a force-quit must restore (cancel). Regression
# for a data-loss bug where the lifecycle guard cancelled every buffer on quit,
# clobbering `:wq`.
test_wq_keeps_saved_edits() {
    f="$work_dir/wq.md"
    printf 'ORIGINAL\n' >"$f"
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"EDITED-VIA-WQ"}); vim.cmd("wq")' "$f"
    got=$(cat "$f")
    if [ "$got" = "EDITED-VIA-WQ" ]; then
        pass ":wq keeps saved edits (return, not cancel)"
    else
        fail ":wq keeps saved edits (return, not cancel)" "status=$run_fresh_status content=$got"
    fi
}

test_qbang_restores_original() {
    f="$work_dir/qbang.md"
    printf 'ORIGINAL\n' >"$f"
    before=$(bytes_of "$f")
    run_fresh 'vim.api.nvim_buf_set_lines(0,0,-1,false,{"UNSAVED-EDIT"}); vim.cmd("q!")' "$f"
    after=$(bytes_of "$f")
    if [ "$before" = "$after" ]; then
        pass ":q! with unsaved edits restores the original (cancel)"
    else
        fail ":q! with unsaved edits restores the original (cancel)" "before=$before after=$after"
    fi
}

test_successful_return
test_wq_keeps_saved_edits
test_qbang_restores_original
test_cancel_no_final_newline
test_cancel_one_newline
test_cancel_crlf
test_cancel_bom
test_cancel_empty
test_cancel_unicode
test_cancel_trailing_blanks
test_missing_file
test_unknown_target
test_spaces_in_filename
test_simulated_crash_restores_backup
test_write_permission_failure

printf '%s passed, %s failed\n' "$pass_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
