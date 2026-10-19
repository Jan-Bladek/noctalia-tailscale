#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
setup=0
dry=0
for arg in "$@"; do
  case "$arg" in
    --setup-system) setup=1 ;;
    --dry-run) dry=1 ;;
    --help) echo 'Usage: ./install.sh [--setup-system] [--dry-run]'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
if (( EUID == 0 )); then echo 'Run as your desktop user, not root.' >&2; exit 1; fi
run() {
  if (( dry )); then printf '%q ' "$@"; printf '\n'; else "$@"; fi
}
if (( setup )); then
  # Distribution ID is read as data, never evaluated as shell code.
  distro=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '\"')
  case "$distro" in
    arch|endeavouros|cachyos|manjaro)
      # A full upgrade avoids unsupported Arch partial upgrades.
      run sudo pacman -Syu --needed tailscale python xdg-utils
      ;;
    fedora)
      if ! command -v tailscale >/dev/null; then
        run sudo curl --fail --show-error --location --proto '=https' --tlsv1.2 \
          https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
          -o /etc/yum.repos.d/tailscale.repo
      fi
      run sudo dnf install -y tailscale python3 xdg-utils
      ;;
    *) echo "Unsupported distribution: $distro (use without --setup-system to copy the plugin)" >&2; exit 1 ;;
  esac
  run sudo systemctl enable --now tailscaled
  # Grant only this desktop user Tailscale's documented operator role.
  run sudo tailscale set "--operator=$(id -un)"
fi
if (( ! dry )); then
  for tool in noctalia python3 tailscale xdg-open; do
    command -v "$tool" >/dev/null || { echo "Missing $tool; install dependencies first." >&2; exit 1; }
  done
fi
destination="${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/tailscale"
if [[ -e "$destination" ]]; then
  run cp -a -- "$destination" "$destination.backup.$(date +%s)"
fi
run mkdir -p -- "$destination"
for file in plugin.toml widget.luau panel.luau service.luau backend.py; do
  run install -m 644 -- "$ROOT/tailscale/$file" "$destination/$file"
done
printf '\nPlugin destination: %s\n' "$destination"
printf '%s\n' 'In Noctalia Settings → Plugins enable Jan-Bladek/tailscale.' \
  'Then add the Jan-Bladek/tailscale:status widget to your bar.' \
  'If it is not listed yet, restart Noctalia to rediscover local plugins.'
