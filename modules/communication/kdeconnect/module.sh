#!/usr/bin/env bash
## KDE Connect — shared Plasma/Hyprland companion with LAN-scoped firewall rules
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"

requires=(system/security/ufw)
packages=(arch:kdeconnect fedora:kde-connect)

# The package owns its cross-desktop XDG autostart and D-Bus activation.
module_entrypoint "$@"
