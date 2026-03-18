# pkg-update-scripts

Automated update system for third-party packages on Linux, covering tools that live
outside the standard APT ecosystem — AppImages, standalone binaries from GitHub, and
`.deb` packages not tracked by the system package manager. This tool was created with personal use in mind. Created and tested in a Linux Mint installation.

---

## The problem this solves

Most Linux systems handle APT and Flatpak updates automatically. What they don't handle
is everything else: AppImages, CLI tools downloaded from GitHub
releases, and `.deb` packages from external sources. Without automation, these stay
outdated indefinitely unless you remember to update them by hand.

This project builds a self-contained update pipeline for those tools, designed around
one principle: after setup, you should never have to think about it again.

---

## Design decisions

Understanding why the project is structured this way matters more than the code itself.

### Two services, not one

Updates are split into a user-level service and a system-level service. This is not
arbitrary — it follows the principle of least privilege. AppImages and standalone
binaries install into `$HOME` and require no elevated permissions to update. Debian
packages require `dpkg`, which writes to system paths and needs root. Mixing these
in a single service would mean running everything as root, which is unnecessary and
creates a larger attack surface.

The split maps directly to how systemd thinks about services: `~/.config/systemd/user/`
for unprivileged operations, `/etc/systemd/system/` for system-wide operations.

### Tool selection

Each tool in the stack was chosen for a specific reason, and several alternatives were
evaluated and rejected.

**appman** manages AppImages. It maintains a database of over 2000 apps, tracks installed
versions by comparing against upstream sources, and installs everything into `$HOME`
without root. GearLever was the previous tool for this and was replaced because it lacked
reliable CLI support for automation.

**install-release (`ir`)** handles standalone CLI binaries from GitHub and GitLab releases.
It tracks installed versions in a JSON state file that can be committed to Git, making
the tool list portable across machines. Crucially, `ir upgrade` and `ir upgrade --pkg`
operate independently — running `ir upgrade` in the user service safely checks `.deb`
package updates without attempting installation, while `ir upgrade --pkg` in the system
service performs the actual privileged install.

**deb-get** manages `.deb` packages from external sources like third-party repositories
and direct downloads. One non-obvious detail: `deb-get upgrade` without flags internally
calls `apt-get install --only-upgrade` for packages installed via repositories, which
overlaps with the system's own APT automation. The `--dg-only` flag restricts the
operation to what deb-get itself installed, avoiding that overlap.

**bauh** was evaluated as a GUI companion for non-technical users but was dropped — the project isn't updated since January 2024 and is incompatible with Python 3.14+. I wasn't able to find a maintained GUI that covers all these formats in a single interface.

### systemd timer over cron

The `Persistent=true` directive is the deciding factor. If the system is off when a
cron job is scheduled, that job simply doesn't run. A persistent systemd timer checks
on boot whether it missed any scheduled runs and executes immediately if so. For a
machine that isn't always on, this is the difference between reliable and unreliable
automation.

### install.sh generates, not links, systemd units

The `.service` files in the repository contain path placeholders (`__SCRIPTS_USER_DIR__`,
`__SCRIPTS_SYSTEM_DIR__`). During installation, `install.sh` copies these files and
uses `sed` to substitute the actual absolute paths before placing them in the systemd
directories. This keeps the repository clean — no machine-specific paths are ever
committed — while still producing valid, absolute-path unit files that systemd requires.
Shell scripts use symlinks instead, since their content needs no processing.

---

## Stack

| Need | CLI tool | Service level |
|---|---|---|
| AppImages, portables | appman | user |
| Standalone CLI binaries (GitHub/GitLab) | install-release (`ir`) | user |
| `.deb` from GitHub, not in deb-get | install-release (`ir --pkg`) | system |
| `.deb` from external sources | deb-get | system |
| Flatpak | flatpak (native) | user (existing) |
| APT | apt (native) | system (existing) |

---

## Repository structure

```
pkg-update-scripts/
├── install.sh                        # validates, configures, and activates everything
├── scripts/
│   ├── lib/
│   │   └── common.sh                 # shared logging and utilities
│   ├── user/                         # runs as current user — no elevated permissions
│   │   ├── update-all-user.sh        # user orchestrator
│   │   ├── update-appman.sh          # AppImages via appman -u
│   │   └── update-ir.sh              # CLI binaries via ir upgrade
│   └── system/                       # runs as root
│       ├── update-all-system.sh      # system orchestrator
│       ├── update-deb-get.sh         # external .deb via deb-get upgrade --dg-only
│       └── update-ir-pkg.sh          # GitHub .deb via ir upgrade --pkg
├── systemd/
│   ├── user/                         # installed to ~/.config/systemd/user/
│   │   ├── pkg-update-user.service
│   │   └── pkg-update-user.timer
│   └── system/                       # installed to /etc/systemd/system/
│       ├── pkg-update-system.service
│       └── pkg-update-system.timer
└── logs/
    └── .gitkeep
```

---

## Requirements

The following tools must be installed before running `install.sh`. Each link points to
the official installation instructions.

- **appman** — [github.com/ivan-hc/AM](https://github.com/ivan-hc/AM) (choose option 2, AppMan mode)
- **install-release** — [github.com/Rishang/install-release](https://github.com/Rishang/install-release) via `pip install install-release`
- **deb-get** — [github.com/wimpysworld/deb-get](https://github.com/wimpysworld/deb-get)

---

## Installation

```bash
git clone https://github.com/semymax/pkg-update-scripts.git
cd pkg-update-scripts
bash install.sh
```

`install.sh` will verify that all expected files are present, check that dependencies
are installed, set executable permissions on scripts, generate and install systemd units
with correct paths, and activate both timers. If any step fails, it exits with a
non-zero code and reports what went wrong before making any changes to the system.

After installation, verify the timers are active:

```bash
systemctl --user status pkg-update-user.timer
sudo systemctl status pkg-update-system.timer
```

---

## Logs

Each run appends to a dated log file in `~/.local/state/pkg-automation/`. This follows
the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)
for application state data. To inspect the current day's log:

```bash
cat ~/.local/state/pkg-automation/$(date +%Y-%m-%d).log
```

System-level runs are also captured by journald and can be queried with:

```bash
journalctl -u pkg-update-system.service
```

---

## Planned improvements

Several extensions are already designed but not yet implemented, documented here to
make the project's direction explicit.

**Failure notifications** — `OnFailure=` directives in both service units reference
error notifier services that don't exist yet. These would use `Gio.Notification` via
PyGObject to send a desktop notification when either orchestrator exits with a non-zero
code, so failures don't go unnoticed.

**AM system-wide** — The current stack uses appman (user mode) exclusively. If the
system ever needs to serve multiple users or requires apps installed in `/opt`, `am`
(system mode) can be added to the system service with a single line in
`update-all-system.sh`. The architecture already anticipates this.

**Log rotation** — Logs accumulate indefinitely. A cleanup step removing entries older
than 30 days should be added to the orchestrators or handled by a separate timer.

**ir state in Git** — install-release stores its state in
`~/.local/config/install_release/`. Committing this file makes the installed tool list
portable across machines and provides a history of what was installed and when.