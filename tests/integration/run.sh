#!/bin/sh
# Runs every shell-driven integration spec under tests/integration/ and
# aggregates their pass/fail counts. Exit code: 0 iff every spec exited 0.
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

overall_status=0

for spec in "$script_dir"/*_spec.sh; do
    printf '=== %s ===\n' "$(basename "$spec")"
    "$spec"
    status=$?
    if [ "$status" -ne 0 ]; then
        overall_status=1
    fi
done

exit "$overall_status"
