#!/bin/sh
# Existing-server (`--server`) integration tests (WP-H). Starts one real
# headless Neovim server and drives bin/prompt-nvim's `--server` mode against
# it, since Neovim has no `--remote-wait` (E5600) - the launcher polls
# `prompt.remote.is_open(session_id)` instead, and so do these tests.
#
# Run directly: tests/integration/server_spec.sh
# Exit code: 0 if every test passed, 1 otherwise.
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(CDPATH='' cd -- "$script_dir/../.." && pwd)
launcher="$root_dir/bin/prompt-nvim"
init="$root_dir/tests/minimal_init.lua"

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

work_dir=$(mktemp -d)
sock="$work_dir/server.sock"
server_log="$work_dir/server.log"
server_pid=""

# shellcheck disable=SC2329 # invoked indirectly via `trap ... EXIT INT TERM`
cleanup() {
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || true
    chmod -R u+rwx "$work_dir" 2>/dev/null || true
    rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

remote_expr() {
    nvim --headless --server "$sock" --remote-expr "$1" 2>/dev/null
}

wait_for_socket() {
    n=0
    while [ ! -S "$sock" ] && [ "$n" -lt 100 ]; do
        sleep 0.05
        n=$((n + 1))
    done
    [ -S "$sock" ]
}

# wait_for_condition EXPR EXPECTED [ITERS]
wait_for_condition() {
    expr="$1"
    expected="$2"
    iters="${3:-100}"
    n=0
    while [ "$n" -lt "$iters" ]; do
        got=$(remote_expr "$expr")
        [ "$got" = "$expected" ] && return 0
        sleep 0.05
        n=$((n + 1))
    done
    return 1
}

# session_probe FILE ACCESSOR -> evaluates ACCESSOR (a Lua statement string
# that can `return` something) with `s` bound to that file's
# vim.b[bufnr].prompt_session (or nil). Kept generic and quote-free so ACCESSOR
# can be any short expression without fighting shell/VimL/Lua quoting.
session_probe() {
    file="$1"
    accessor="$2"
    remote_expr "luaeval('(function() local b=vim.fn.bufnr(vim.fn.fnamemodify([[$file]],[[:p]])); local s=vim.b[b].prompt_session; $accessor end)()')"
}

cancel_session_buffer() {
    file="$1"
    remote_expr "luaeval('(function() local b=vim.fn.bufnr(vim.fn.fnamemodify([[$file]],[[:p]])); require(\"prompt.bridge\").cancel(b); return 1 end)()')"
}

setsid nvim --headless -u "$init" --listen "$sock" -c 'lua require("prompt").setup({})' </dev/null >"$server_log" 2>&1 &
server_pid=$!

if ! wait_for_socket; then
    fail "server startup" "socket never appeared at $sock"
    printf '%s passed, %s failed\n' "$pass_count" "$fail_count"
    exit 1
fi

test_single_session_metadata_and_unblock() {
    f="$work_dir/single.md"
    printf 'hello\n' >"$f"

    PROMPT_NVIM_SESSION=SOLO "$launcher" --server "$sock" --target codex -- "$f" &
    launcher_pid=$!

    if ! wait_for_condition "luaeval('require(\"prompt.remote\").is_open(\"SOLO\")')" "1" 100; then
        fail "single session: buffer opens on the server" "is_open never became 1"
        kill "$launcher_pid" 2>/dev/null || true
        wait "$launcher_pid" 2>/dev/null
        return
    fi
    pass "single session: buffer opens on the server"

    target=$(session_probe "$f" 'if not s then return [[NONE]] end; return s.target or [[NIL]]')
    remote_flag=$(session_probe "$f" 'if not s then return [[NONE]] end; return tostring(s.remote)')
    bridge_flag=$(session_probe "$f" 'if not s then return [[NONE]] end; return tostring(s.bridge)')
    state=$(session_probe "$f" 'if not s then return [[NONE]] end; return s.state or [[NIL]]')
    cwd=$(session_probe "$f" 'if not s then return [[NONE]] end; return s.launch_cwd or [[NIL]]')

    if [ "$target" = "codex" ] && [ "$remote_flag" = "true" ] && [ "$bridge_flag" = "true" ] && [ "$state" = "attached" ] && [ -n "$cwd" ] && [ "$cwd" != "NIL" ]; then
        pass "single session: vim.b.prompt_session has correct target/remote/bridge/state/cwd"
    else
        fail "single session: vim.b.prompt_session has correct target/remote/bridge/state/cwd" \
            "target=$target remote=$remote_flag bridge=$bridge_flag state=$state cwd=$cwd"
    fi

    cancel_session_buffer "$f" >/dev/null

    if wait_for_condition "luaeval('require(\"prompt.remote\").is_open(\"SOLO\")')" "0" 100; then
        pass "single session: is_open goes to 0 after cancel"
    else
        fail "single session: is_open goes to 0 after cancel" "is_open never became 0"
    fi

    wait "$launcher_pid"
    status=$?
    if [ "$status" -eq 0 ]; then
        pass "single session: the launcher's poll unblocks and exits 0"
    else
        fail "single session: the launcher's poll unblocks and exits 0" "status=$status"
    fi

    if wait_for_socket; then
        pass "single session: the server itself stays alive"
    else
        fail "single session: the server itself stays alive" "socket disappeared"
    fi
}

test_two_sessions_independent_and_isolated() {
    f1="$work_dir/session-a.md"
    f2="$work_dir/session-b.md"
    printf 'file A\n' >"$f1"
    printf 'file B\n' >"$f2"

    PROMPT_NVIM_SESSION=SESSA "$launcher" --server "$sock" --target codex -- "$f1" &
    pid_a=$!
    PROMPT_NVIM_SESSION=SESSB "$launcher" --server "$sock" --target claude -- "$f2" &
    pid_b=$!

    open_a="0"
    open_b="0"
    wait_for_condition "luaeval('require(\"prompt.remote\").is_open(\"SESSA\")')" "1" 100 && open_a="1"
    wait_for_condition "luaeval('require(\"prompt.remote\").is_open(\"SESSB\")')" "1" 100 && open_b="1"

    target_a=$(session_probe "$f1" 'if not s then return [[NONE]] end; return s.target or [[NIL]]')
    target_b=$(session_probe "$f2" 'if not s then return [[NONE]] end; return s.target or [[NIL]]')

    if [ "$open_a" = "1" ] && [ "$open_b" = "1" ] && [ "$target_a" = "codex" ] && [ "$target_b" = "claude" ]; then
        pass "two sessions: both open concurrently with distinct targets"
    else
        fail "two sessions: both open concurrently with distinct targets" \
            "open_a=$open_a open_b=$open_b target_a=$target_a target_b=$target_b"
    fi

    # Regression test: closing session A must not take down session B. This
    # caught a real bug where a bare `bdelete` closed whatever buffer was
    # CURRENT in the server rather than the targeted session's own buffer.
    cancel_session_buffer "$f1" >/dev/null

    closed_a="no"
    wait_for_condition "luaeval('require(\"prompt.remote\").is_open(\"SESSA\")')" "0" 100 && closed_a="yes"
    still_open_b=$(remote_expr "luaeval('require(\"prompt.remote\").is_open(\"SESSB\")')")

    wait "$pid_a"
    status_a=$?

    if [ "$closed_a" = "yes" ] && [ "$still_open_b" = "1" ] && [ "$status_a" -eq 0 ]; then
        pass "two sessions: closing one leaves the other open (regression test)"
    else
        fail "two sessions: closing one leaves the other open (regression test)" \
            "closed_a=$closed_a still_open_b=$still_open_b status_a=$status_a"
    fi

    target_b_after=$(session_probe "$f2" 'if not s then return [[NONE]] end; return s.target or [[NIL]]')
    if [ "$target_b_after" = "claude" ]; then
        pass "two sessions: session B's own metadata is untouched by closing A"
    else
        fail "two sessions: session B's own metadata is untouched by closing A" "target_b_after=$target_b_after"
    fi

    cancel_session_buffer "$f2" >/dev/null
    wait_for_condition "luaeval('require(\"prompt.remote\").is_open(\"SESSB\")')" "0" 100
    wait "$pid_b"
    status_b=$?
    if [ "$status_b" -eq 0 ]; then
        pass "two sessions: session B's own launcher also unblocks cleanly"
    else
        fail "two sessions: session B's own launcher also unblocks cleanly" "status=$status_b"
    fi
}

test_single_session_metadata_and_unblock
test_two_sessions_independent_and_isolated

printf '%s passed, %s failed\n' "$pass_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
