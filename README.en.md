# Noctalia Tailscale

An icon-only bar widget and native panel for **Noctalia 5.x with plugin API 31 or newer**. Supports Arch Linux and derivatives (including Omarchy), and Fedora with DNF. Omarchy is not required.

Features: connect/disconnect, browser sign-in with a clickable/copyable HTTPS link, exit-node selection, local LAN access, subnet routing, Tailscale DNS, incoming-connection blocking, advertising subnets and acting as an exit node. Two theme-aware icons indicate connected/disconnected state. Right-click toggles the connection; left-click opens the panel.

## Install

Install Noctalia first using its [official instructions](https://docs.noctalia.dev/noctalia/getting-started/installation/), then run as your desktop user, **without sudo**:

```bash
git clone https://github.com/Jan-Bladek/noctalia-tailscale.git
cd noctalia-tailscale
./install.sh
```

The installer detects the distribution, installs Tailscale/Python/xdg-utils, starts `tailscaled`, assigns your actual Unix user as the Tailscale operator and copies the plugin to your user data directory. It requests sudo only for system changes. Arch performs a full system upgrade to avoid partial upgrades. Fedora uses the official Tailscale repository without relying on DNF config-manager syntax.

Enable **Jan-Bladek/tailscale** in Noctalia Settings → Plugins, then add **Jan-Bladek/tailscale:status** to the bar. Restart Noctalia if the plugin is not discovered yet.

`Jan-Bladek/tailscale` is the project's plugin identifier, not your login. You sign in to your own Tailscale account. No usernames, home directories, node addresses or tailnet credentials from the author are required.

```bash
./installers/arch.sh       # explicitly select Arch package family
./installers/fedora.sh     # explicitly select Fedora package family
./install.sh --dry-run     # preview without changes
./install.sh --plugin-only # copy/update user files only; no sudo
./install.sh --help
```

Update with `git pull --ff-only` followed by `./install.sh --plugin-only`.

## Paths and shared machines

The installer honors `NOCTALIA_DATA_HOME`, `XDG_DATA_HOME`, `NOCTALIA_STATE_HOME` and `XDG_STATE_HOME`, matching Noctalia's precedence. Defaults are `~/.local/share/noctalia/plugins/tailscale` for the plugin and `~/.local/state/noctalia/plugin-backups` for backups. Custom paths must be absolute; spaces are supported.

Tailscale has one operator per daemon. The installer refuses to silently take this role from another user. Choose `--skip-operator` to leave it unchanged, or `--replace-operator` to explicitly assign it to the current user. Skipping the role does not grant control permissions. All local users access the same system Tailscale daemon/account.

For Fedora Atomic, install Tailscale on the host through rpm-ostree, reboot and configure the service/operator first; then run `./install.sh --plugin-only`. Automatic system setup supports DNF-based Fedora hosts. Run the installer on the host rather than inside Toolbox/Distrobox.

## Usage and checks

Use the panel's switch to connect. If authentication is needed, the browser opens and the panel also provides **Open login link** and **Copy link**. Connections preserve your existing preferences. Advertising routes or acting as an exit node additionally requires IP forwarding and approval in the Tailscale admin console.

```bash
python3 -m unittest discover -s tests -v
lua tests/test_ui.lua
noctalia plugins lint tailscale
bash -n install.sh installers/arch.sh installers/fedora.sh
```

Tests cover backend validation, UI actions and installer file operations with mocked privileged/network commands. Connection and disconnection were tested in a live Noctalia 5.3 session on Omarchy; a physical Fedora install and fresh-account browser login have not been tested.

Licensed under [PolyForm Noncommercial 1.0.0](LICENSE), including the project documentation. Commercial use requires separate permission. Independent of Noctalia and Tailscale.
