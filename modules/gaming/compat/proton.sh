#!/usr/bin/env bash
## Proton helper tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	flathub/com.github.Matoking.protontricks
	flathub/net.davidotek.pupgui2
	flathub/com.vysp3r.ProtonPlus
)
pkg_install "${packages[@]}"
