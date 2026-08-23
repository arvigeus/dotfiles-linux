#!/usr/bin/env bash
## Tor Browser
## https://www.torproject.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.torproject.torbrowser-launcher
)
pkg_install "${packages[@]}"
flatpak_alias tor-browser org.torproject.torbrowser-launcher
