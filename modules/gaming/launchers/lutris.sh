#!/usr/bin/env bash
## Lutris game launcher
## https://lutris.net/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/net.lutris.Lutris
)
pkg_install "${packages[@]}"
flatpak_alias lutris net.lutris.Lutris
