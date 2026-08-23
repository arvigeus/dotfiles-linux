#!/usr/bin/env bash
## Diablo 1 — DevilutionX
## https://github.com/diasurgical/devilutionX
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.diasurgical.DevilutionX
)
pkg_install "${packages[@]}"
flatpak_alias diablo org.diasurgical.DevilutionX
