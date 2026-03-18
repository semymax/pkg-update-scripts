#!/usr/bin/env bash
set -euo pipefail
common_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
if ! [ -f "$common_lib" ]; then
    echo "[AM] common.sh not found: $common_lib"
    exit 1
fi
source "$common_lib"

log_info "=== AppMan: starting update: ==="
# the app can be install as am (global) or appman (user)
# require_cmd am
require_cmd appman || exit 1

# appman -u already checks for its own updates
# log_info "Upgrading am"
# log_info "Upgrading appman"
# run_cmd am -s
# run_cmd appman -s

# using "--debug" creates visual garbage on log file
log_info "Upgrading installed apps"
# run_cmd am -u # --debug
run_cmd appman -u # --debug
log_info "=== AppMan: finished ==="
