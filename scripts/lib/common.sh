#!/usr/bin/env bash
if [[ "$EUID" -eq 0 ]]; then
    # convention for system level logging
    log_file="/var/log/pkg-automation/$(date +%Y-%m-%d).log"
else
    log_file="${XDG_STATE_HOME:-$HOME/.local/state}/pkg-automation/$(date +%Y-%m-%d).log"
fi
log_dir=$(dirname "$log_file")
mkdir -p "$log_dir"

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

# remove log files older than a specified number of days
cleanup_old_logs() {
    local max_days="${1:-30}" # Defaults to 30 days

    log_info "Removing log files older than ${max_days} days from ${log_dir}"

    local deleted_count=0
    while IFS= read -r -d '' old_log; do
        log_info "Deleting: $(basename "$old_log")"
        rm -f "$old_log"
        deleted_count=$((deleted_count + 1))
    done < <(find "$log_dir" -maxdepth 1 -name '*.log' -type f -mtime "+${max_days}" -print0)

    if [ "$deleted_count" -eq 0 ]; then
        log_info "No old logs to remove"
    else
        log_info "Removed ${deleted_count} old log(s)"
    fi
}
