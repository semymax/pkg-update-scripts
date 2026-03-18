#!/usr/bin/env bash
set -uo pipefail
common_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
if ! [ -f "$common_lib" ]; then
    echo "[ALL] common.sh not found: $common_lib"
    exit 1
fi
source "$common_lib"

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"

ok=0
fail=0

run_module() {
    local script="$1"
    local name="$2"

    log_info "--- Starting module: $name ---"

    if bash "${SCRIPTS_DIR}/${script}"; then
        log_info "$name: OK"
        ((ok++))
        return 0
    else
        local status=$?
        log_error "$name: FAILED (exit code: $status)"
        ((fail++))
        return 1
    fi
}

log_info "=== Complete update (user): starting ==="

run_module "update-appman.sh" "appman"
run_module "update-ir.sh" "install-release"

log_info "=== Summary: $ok ok, $fail failed ==="

# exit code reflects if there was an error running any module
exit "$fail"
