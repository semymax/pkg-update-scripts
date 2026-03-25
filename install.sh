#!/usr/bin/env bash
# This will check the integrity of the project,
# check if external dependencies are installed and
# check/change exec permissions
set -euo pipefail

# paths
basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scripts="${basedir}/scripts"
scripts_user_dir="${scripts}/user"
scripts_system_dir="${scripts}/system"

sdunits="${basedir}/systemd"
sdunits_user_dir="${sdunits}/user"
sdunits_system_dir="${sdunits}/system"

# files
# lib
common_lib="${scripts}/lib/common.sh"

# update modules
user_scripts=(
    "update-all-user.sh"
    "update-appman.sh"
    "update-ir.sh"
)

system_scripts=(
    "update-all-system.sh"
    "update-deb-get.sh"
    "update-ir-pkg.sh"
)

# systemd units

user_units=(
    pkg-update-user.timer
    pkg-update-user.service
)

system_units=(
    pkg-update-system.timer
    pkg-update-system.service
)

# ok=0 # not needed for now 
fail=0
scripts_found=()
not_found=()

# Project integrity
echo "--- Checking if files exist ---"
check_integrity() {
    # $1: type; $2: file
    if [ -f "$2" ]; then
        echo "  $2 - file found (ok)"
        if [ "$1" == "script" ]; then
            scripts_found+=("$2")
        fi
        # ok=$((ok + 1)) # no use for now
    else
        echo "  $2 - expected file not found (error)"
        not_found+=("$2")
        fail=$((fail + 1))
    fi
}

check_integrity "script" "$common_lib"

for user_script in "${user_scripts[@]}"; do
    check_integrity "script" "${scripts_user_dir}/${user_script}"
done

for system_script in "${system_scripts[@]}"; do
    check_integrity "script" "${scripts_system_dir}/${system_script}"
done

for user_unit in "${user_units[@]}"; do
    check_integrity "unit" "${sdunits_user_dir}/${user_unit}"
done

for system_unit in "${system_units[@]}"; do
    check_integrity "unit" "${sdunits_system_dir}/${system_unit}"
done

if [[ "$fail" -gt 0 ]]; then
    echo "=====  INTEGRITY ERROR  ====="
    echo "Expected files not found:"
    for file in "${not_found[@]}"; do
        echo "$file"
    done
    exit "$fail"
else
    echo "[INFO] All expected files present"
fi

# check if dependancies are installed
echo "--- Checking if dependencies are installed ---"
source "$common_lib"
deps=(appman ir deb-get)
deps_not_found=()
failed_deps=0

for cmd in "${deps[@]}"; do
    if ! require_cmd "$cmd"; then
        echo "  - ${cmd} not installed."
        deps_not_found+=("$cmd")
        failed_deps=$((failed_deps + 1))
    else
        echo "  - found ${cmd}"
    fi
done

if [ "$failed_deps" -gt 0 ]; then
    echo "==== [ERROR] ===="
    echo "Dependencies not installed."
    for dep in "${deps_not_found[@]}"; do
        echo "  - ${dep}"
    done
    echo "Refer to https://github.com/semymax/pkg-update-scripts#requirements"
    exit "$failed_deps"
else
    echo "[INFO] All good with dependencies"
fi

for script in "${scripts_found[@]}"; do
    chmod +x "$script"
done

# Create links to the services
echo "--- Installing systemd units ---"
mkdir -p "${HOME}/.config/systemd/user"
for unit in "${user_units[@]}"; do
    dest="${HOME}/.config/systemd/user/${unit}"
    cp "${sdunits_user_dir}/${unit}" "$dest"
    sed -i "s|__SCRIPTS_USER_DIR__|${scripts_user_dir}|g" "$dest"
    log_info "Installed ${unit} -> ${dest}"
done

for unit in "${system_units[@]}"; do
    dest="/etc/systemd/system/${unit}"
    sudo cp "${sdunits_system_dir}/${unit}" "$dest"
    sudo sed -i "s|__USER_HOME__|${HOME}|g" "$dest"
    sudo sed -i "s|__SCRIPTS_SYSTEM_DIR__|${scripts_system_dir}|g" "$dest"
    log_info "Installed ${unit} -> ${dest}"
done

echo "--- Activating systemd timers ---"

# user
systemctl --user daemon-reload
systemctl --user enable --now pkg-update-user.timer
log_info "User timer activated"

# system
sudo systemctl daemon-reload
sudo systemctl enable --now pkg-update-system.timer
log_info "System timer activated"

# confirmation
echo ""
systemctl --user status pkg-update-user.timer --no-pager
sudo systemctl status pkg-update-system.timer --no-pager

echo "=== Installation complete ==="
