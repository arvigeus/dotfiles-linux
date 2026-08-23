#!/usr/bin/env bash
## Dev Toolbox
## https://github.com/aleiepure/devtoolbox
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/me.iepure.devtoolbox
)
pkg_install "${packages[@]}"
flatpak_alias devtoolbox me.iepure.devtoolbox
