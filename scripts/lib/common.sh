#!/usr/bin/env bash
log_file="${XDG_STATE_HOME:-$HOME/.local/state}/pkg-automation/$(date +%Y-%m-%d).log"
mkdir -p "$(dirname "$log_file")"

_logger() {
    echo "($(date +%H:%M:%S)) [$1] - $2" | tee -a "$log_file" 
}

log_info() {
    _logger "INFO" "$1"
}

log_warn() {
    _logger "WARN" "$1"
}

log_error() {
    _logger "ERROR" "$1"
}

require_cmd() {
    if ! command -v "$1" > /dev/null 2>&1; then
        log_error "Command not found: $1"
        return 1
    fi
}

run_cmd() {
    log_info "Executing $*"
    if "$@" 2>&1 | tee -a "$log_file"; then
        return
    else
        status=$?
        log_error "Command failed (exit code: $status)"
        return "$status"
    fi
}
