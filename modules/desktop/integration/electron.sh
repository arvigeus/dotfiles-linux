#!/usr/bin/env bash
## Electron — cross-platform desktop apps
## https://www.electronjs.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

## Electron apps — force native Wayland backend (HiDPI, fractional scaling)
system_set_env electron ELECTRON_OZONE_PLATFORM_HINT wayland
