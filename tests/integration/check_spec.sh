#!/bin/sh
# `--check` integration tests. The command is documented as "Validate the
# installation", but it used to only resolve `nvim` on PATH — it reported OK on
# a machine where prompt.nvim was never installed, and said nothing about the
# launcher/plugin version pairing that silently breaks the editor flow.
#
# Run directly: tests/integration/check_spec.sh
# Exit code: 0 if every test passed, 1 otherwise. Emits TAP-ish "ok"/"not ok"
# lines plus a final "N passed, M failed" summary, same shape as tests/run.lua.
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
# shellcheck disable=SC2329 # invoked indirectly via `trap ... EXIT INT TERM`
cleanup() {
    rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

# Drive nvim with the repo's minimal init so --check sees the plugin regardless
# of whatever the developer's own config does. setup() is called explicitly:
# minimal_init only prepends the runtimepath, and target resolution goes through
# `registry.has()`, which is empty until the built-in targets are registered.
# Every documented install calls setup(), so this matches a real one.
nvim_bin=$(command -v nvim || echo nvim)
plugin_nvim="$work_dir/nvim-with-plugin"
cat >"$plugin_nvim" <<EOF
#!/bin/sh
exec "$nvim_bin" -u "$init" -c 'lua require("prompt").setup({})' "\$@"
EOF
chmod +x "$plugin_nvim"

# A Neovim that loads no config at all, standing in for a machine where the
# plugin was never installed.
bare_nvim="$work_dir/nvim-bare"
cat >"$bare_nvim" <<EOF
#!/bin/sh
exec "$nvim_bin" --clean "\$@"
EOF
chmod +x "$bare_nvim"

test_reports_ok_with_the_plugin_present() {
    out=$(PROMPT_NVIM_EXECUTABLE="$plugin_nvim" timeout 60 sh "$launcher" --check 2>&1)
    status=$?
    if [ "$status" -eq 0 ] &&
        printf '%s\n' "$out" | grep -q 'plugin version' &&
        printf '%s\n' "$out" | grep -q 'prompt-nvim: OK'; then
        pass "--check reports OK and the plugin version when installed"
    else
        fail "--check reports OK and the plugin version when installed" "status=$status out=$out"
    fi
}

# The regression: this case used to print "OK".
test_detects_missing_plugin() {
    out=$(PROMPT_NVIM_EXECUTABLE="$bare_nvim" timeout 60 sh "$launcher" --check 2>&1)
    status=$?
    if [ "$status" -ne 0 ] && printf '%s\n' "$out" | grep -q 'not loadable'; then
        pass "--check fails when prompt.nvim is not installed"
    else
        fail "--check fails when prompt.nvim is not installed" "status=$status out=$out"
    fi
}

test_detects_version_mismatch() {
    stale="$work_dir/stale-launcher"
    sed 's/^VERSION=".*"/VERSION="0.0.1-stale"/' "$launcher" >"$stale"
    chmod +x "$stale"

    out=$(PROMPT_NVIM_EXECUTABLE="$plugin_nvim" timeout 60 sh "$stale" --check 2>&1)
    status=$?
    if [ "$status" -ne 0 ] && printf '%s\n' "$out" | grep -q 'does not match plugin'; then
        pass "--check fails on a launcher/plugin version mismatch"
    else
        fail "--check fails on a launcher/plugin version mismatch" "status=$status out=$out"
    fi
}

test_missing_nvim_still_fails() {
    out=$(PROMPT_NVIM_EXECUTABLE=definitely-not-a-real-nvim sh "$launcher" --check 2>&1)
    status=$?
    if [ "$status" -ne 0 ] && printf '%s\n' "$out" | grep -q 'nvim not found'; then
        pass "--check still fails when nvim is missing"
    else
        fail "--check still fails when nvim is missing" "status=$status out=$out"
    fi
}

# A resolvable target is reported, but its absence is informational: the target
# normally arrives from the shell wrapper at edit time, not at check time.
test_target_is_reported_without_failing() {
    with_target=$(PROMPT_NVIM_TARGET=codex PROMPT_NVIM_EXECUTABLE="$plugin_nvim" \
        timeout 60 sh "$launcher" --check 2>&1)
    with_status=$?

    if [ "$with_status" -eq 0 ] && printf '%s\n' "$with_target" | grep -q 'target resolves to codex'; then
        pass "--check reports the resolved target"
    else
        fail "--check reports the resolved target" "status=$with_status out=$with_target"
    fi
}

test_reports_ok_with_the_plugin_present
test_detects_missing_plugin
test_detects_version_mismatch
test_missing_nvim_still_fails
test_target_is_reported_without_failing

printf '%s passed, %s failed\n' "$pass_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
