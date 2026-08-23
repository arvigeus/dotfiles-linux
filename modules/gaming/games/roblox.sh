#!/usr/bin/env bash
## Roblox through Sober
## https://www.roblox.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.vinegarhq.Sober
)
pkg_install "${packages[@]}"
flatpak_alias roblox org.vinegarhq.Sober

# The previous user-scoped input-device override is intentionally omitted;
# there is no user Flatpak installation or user D-Bus session during the build.
