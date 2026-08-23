#!/usr/bin/env bash
## Telegram desktop client
## https://telegram.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.telegram.desktop
)
pkg_install "${packages[@]}"
flatpak_alias telegram org.telegram.desktop
