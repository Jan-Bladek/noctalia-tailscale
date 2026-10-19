#!/usr/bin/env bash
# Install as the desktop user. Only package/service operations use sudo.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
setup=1
dry=0
skip_operator=0
replace_operator=0
distro_override=auto
usage() {
  cat <<'HELP'
Usage: ./install.sh [options]
  --setup-system        Install dependencies, start tailscaled (default)
  --plugin-only         Copy the plugin without sudo or system changes
  --distro auto|arch|fedora  Select package family (default: auto)
  --skip-operator       Keep the existing Tailscale operator unchanged
  --replace-operator    Allow assigning another user's operator role to this user
  --dry-run             Print planned commands without changing anything
  --help                Show help

Run as the user who runs Noctalia, without sudo. Requires Noctalia 5.x
with plugin API >= 31. Use --plugin-only on Fedora Atomic after installing
Tailscale and configuring its service/operator on the host.
HELP
}
while (( $# )); do
  case "$1" in
    --setup-system) setup=1 ;;
    --plugin-only) setup=0 ;;
    --dry-run) dry=1 ;;
    --skip-operator) skip_operator=1 ;;
    --replace-operator) replace_operator=1 ;;
    --distro)
      (( $# >= 2 )) || { echo '--distro needs auto, arch or fedora' >&2; exit 2; }
      distro_override=$2; shift
      case "$distro_override" in auto|arch|fedora) ;; *) echo 'Invalid --distro value' >&2; exit 2 ;; esac
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
if (( EUID == 0 )); then
  echo 'Run as your desktop user without sudo: ./install.sh (sudo is requested only for system setup).' >&2
  exit 1
fi
run() {
  if (( dry )); then printf '%q ' "$@"; printf '\n'; else "$@"; fi
}
require_command() {
  command -v "$1" >/dev/null || { echo "Missing $1. $2" >&2; exit 1; }
}
# Noctalia resolves these variables in this order. Keep all user files in the
# same locations as the shell, including installations with custom data roots.
data_home="${NOCTALIA_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}}"
state_home="${NOCTALIA_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}}"
for directory in "$data_home" "$state_home"; do
  [[ "$directory" == /* ]] || { echo "Data/state directories must be absolute: $directory" >&2; exit 1; }
done
desktop_user=$(id -un)
if (( ! dry )); then
  require_command noctalia 'Install Noctalia 5.x (plugin API >= 31) first; see README.md.'
fi
if (( setup )); then
  # os-release is read as data, never sourced or evaluated.
  distro=$(sed -n 's/^ID=//p' /etc/os-release | tr -d "\"'")
  distro_like=$(sed -n 's/^ID_LIKE=//p' /etc/os-release | tr -d "\"'")
  family=$distro_override
  if [[ "$family" == auto ]]; then
    family=$distro
    for candidate in "$distro" $distro_like; do
      case "$candidate" in
        arch|omarchy|endeavouros|cachyos|manjaro) family=arch; break ;;
        fedora) family=fedora; break ;;
      esac
    done
  fi
  case "$family" in arch|fedora) ;; *) echo "Unsupported distribution: $distro (use --plugin-only if dependencies are already installed)" >&2; exit 1 ;; esac
  if [[ "$family" == fedora && -e /run/ostree-booted ]]; then
    echo 'Fedora Atomic: install Tailscale on the host with rpm-ostree, reboot, configure tailscaled/operator, then run ./install.sh --plugin-only. See README.md.' >&2
    exit 1
  fi
  if (( ! dry )); then
    require_command sudo 'Install sudo or ask an administrator to set up Tailscale, then use --plugin-only.'
    require_command systemctl 'This installer requires a systemd host.'
    if [[ "$family" == arch ]]; then require_command pacman 'Use --distro fedora on Fedora.'
    else require_command dnf 'Use --distro arch on Arch Linux.'; fi
  fi
  case "$family" in
    arch)
      # Full upgrade avoids unsupported Arch partial upgrades.
      run sudo pacman -Syu --needed tailscale python xdg-utils
      ;;
    fedora)
      # Installing the repo file directly works with both DNF 4 and DNF 5.
      if [[ ! -f /etc/yum.repos.d/tailscale.repo ]]; then
        if ! command -v curl >/dev/null; then run sudo dnf install -y curl; fi
        repo_tmp="${TMPDIR:-/tmp}/noctalia-tailscale-repo.DRY-RUN"
        if (( ! dry )); then
          repo_tmp=$(mktemp)
          trap 'rm -f -- "$repo_tmp"' EXIT
        fi
        run curl --fail --show-error --location --proto '=https' --tlsv1.2 \
          https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o "$repo_tmp"
        run sudo install -m 644 -- "$repo_tmp" /etc/yum.repos.d/tailscale.repo
      fi
      run sudo dnf install -y tailscale python3 xdg-utils
      ;;
  esac
  run sudo systemctl enable --now tailscaled
  if (( ! skip_operator )); then
    if (( ! dry )); then
      current_operator=$(sudo tailscale debug prefs | python3 -c 'import json,sys; print(json.load(sys.stdin).get("OperatorUser") or "")')
      if [[ -n "$current_operator" && "$current_operator" != "$desktop_user" ]] && (( ! replace_operator )); then
        echo "Tailscale is already managed by '$current_operator'. Use --skip-operator to keep that role, or --replace-operator to assign it to '$desktop_user'." >&2
        exit 1
      fi
    fi
    run sudo tailscale set "--operator=$desktop_user"
  fi
fi
if (( ! dry )); then
  for tool in python3 tailscale xdg-open; do
    require_command "$tool" 'Run ./install.sh for system setup, or install the dependencies manually.'
  done
fi
destination="$data_home/noctalia/plugins/tailscale"
backup_root="$state_home/noctalia/plugin-backups"
# Move legacy backups out of discovery so they cannot shadow the new plugin.
for legacy in "$(dirname -- "$destination")"/tailscale.backup.*; do
  if [[ -d "$legacy" && -f "$legacy/plugin.toml" ]]; then
    run mkdir -p -- "$backup_root"
    run mv -- "$legacy" "$backup_root/$(basename -- "$legacy").migrated.$$"
  fi
done
if [[ -e "$destination" ]]; then
  run mkdir -p -- "$backup_root"
  run cp -a -- "$destination" "$backup_root/tailscale.$(date +%s).$$"
fi
run mkdir -p -- "$destination"
# Helpers first, entries next, manifest last: hot reloads must find dependencies.
for file in icons.luau backend.py widget.luau panel.luau service.luau plugin.toml; do
  run install -m 644 -- "$ROOT/tailscale/$file" "$destination/$file"
done
printf '\nDesktop user: %s\nPlugin destination: %s\n' "$desktop_user" "$destination"
printf '%s\n' 'In Noctalia Settings → Plugins enable Jan-Bladek/tailscale.' \
  'Then add the Jan-Bladek/tailscale:status widget to your bar.' \
  'If it is not listed yet, restart Noctalia to rediscover local plugins.'
