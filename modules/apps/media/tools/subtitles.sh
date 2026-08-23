#!/usr/bin/env bash
## Subtitle Composer
## https://subtitlecomposer.kde.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.kde.subtitlecomposer
)
pkg_install "${packages[@]}"
flatpak_alias subtitlecomposer org.kde.subtitlecomposer
flatpak_alias subtitle-composer org.kde.subtitlecomposer
