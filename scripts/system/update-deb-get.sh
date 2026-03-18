#!/usr/bin/env bash
set -euo pipefail
common_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
if ! [ -f "$common_lib" ]; then
    echo "[DEB-GET] common.sh not found: $common_lib"
    exit 1
fi
source "$common_lib"

log_info "=== Deb-Get: updating apps ==="
log_info "Checking if deb-get is installed"
require_cmd deb-get

run_cmd deb-get update --quiet
run_cmd deb-get upgrade --dg-only
log_info "=== Deb-Get: finished ==="
