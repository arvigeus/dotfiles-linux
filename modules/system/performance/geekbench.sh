#!/usr/bin/env bash
## Geekbench 6
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/com.geekbench.Geekbench6
)
pkg_install "${packages[@]}"
flatpak_alias geekbench com.geekbench.Geekbench6
