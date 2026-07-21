#!/bin/sh
# Install/version-mismatch smoke tests (#19): `:checkhealth prompt` must
# clearly surface (a) the launcher missing from PATH, and (b) a launcher
# whose --version disagrees with the loaded plugin's lua/prompt/version.lua -
# both are meant to be actionable warnings, not silent or fatal.
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(CDPATH='' cd -- "$script_dir/../.." && pwd)
init="$root_dir/tests/minimal_init.lua"
capture_script="$script_dir/capture_health.lua"

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

# Resolve nvim's absolute path ONCE, under the normal PATH. The health tests
# below run nvim with a stripped-down PATH to hide `prompt-nvim`; if we invoked
# nvim by bare name there, that same stripped PATH would also fail to find nvim
# itself on CI (where it lives in a toolcache dir, not /usr/bin). Calling it by
# absolute path launches nvim regardless, while the stripped PATH still governs
# what nvim sees for its own `executable("prompt-nvim")` check.
nvim_bin=$(command -v nvim || echo nvim)

# capture_checkhealth PATH_VALUE -> writes the report to $work_dir/health.txt
capture_checkhealth() {
    out="$work_dir/health.txt"
    rm -f "$out"
    PATH="$1" PROMPT_NVIM_TEST_HEALTH_OUT="$out" \
        "$nvim_bin" --headless -u "$init" -l "$capture_script" >/dev/null 2>&1
    cat "$out" 2>/dev/null
}

test_launcher_missing_from_path() {
    # A minimal PATH with no prompt-nvim on it anywhere (real nvim is already
    # resolved before this env var takes effect, so nvim itself still runs).
    report=$(capture_checkhealth "/usr/bin:/bin")
    if printf '%s\n' "$report" | grep -q 'prompt-nvim executable not found on PATH'; then
        pass "checkhealth warns when the launcher is missing from PATH"
    else
        fail "checkhealth warns when the launcher is missing from PATH" "report did not contain the expected warning"
    fi
}

test_launcher_version_mismatch_surfaces() {
    fake_bin_dir="$work_dir/fakebin"
    mkdir -p "$fake_bin_dir"
    fake_launcher="$fake_bin_dir/prompt-nvim"
    cat >"$fake_launcher" <<'EOF'
#!/bin/sh
case "$1" in
    --version) printf 'prompt-nvim 9.9.9\n' ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$fake_launcher"

    report=$(capture_checkhealth "$fake_bin_dir:/usr/bin:/bin")
    if printf '%s\n' "$report" | grep -q 'Launcher 9.9.9 does not match plugin'; then
        pass "checkhealth warns on a launcher/plugin version mismatch"
    else
        fail "checkhealth warns on a launcher/plugin version mismatch" "report did not contain the expected mismatch warning"
    fi
}

test_launcher_missing_from_path
test_launcher_version_mismatch_surfaces

printf '%s passed, %s failed\n' "$pass_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
