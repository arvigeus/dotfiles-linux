#!/usr/bin/env bash
## System fonts
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	nerd-fonts # icons, programming
	adwaita-fonts
)

pkg_install "${packages[@]}"
