#!/usr/bin/env bash
# Run after gh auth login. Uses the current authenticated GitHub account.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
gh auth status
if ! git remote get-url origin >/dev/null 2>&1; then
  gh repo create noctalia-tailscale --private --source=. --remote=origin \
    --description 'Tailscale bar widget for Noctalia 5: login, exit nodes and subnet routes'
fi
git push -u origin main
