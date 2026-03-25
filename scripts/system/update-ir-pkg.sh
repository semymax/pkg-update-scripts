#!/usr/bin/env bash
set -euo pipefail
common_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
if ! [ -f "$common_lib" ]; then
    echo "[IR] common.sh not found: $common_lib"
    exit 1
fi
source "$common_lib"

log_info "=== install-release (packages): updating apps ==="
log_info "Checking if ir is installed"
require_cmd ir

run_cmd ir upgrade --pkg -y
log_info "=== Install-Release (packages): finished ==="
