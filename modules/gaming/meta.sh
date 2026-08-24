#!/usr/bin/env bash
## Selectable SteamOS-style Gamescope session and gaming support
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	# Vanilla distro gaming stack.
	arch:ibus
	arch:noto-fonts
	arch:ttf-dejavu
	arch:pacman-contrib
	arch:fakeroot
	fedora:ibus
	fedora:google-noto-sans-fonts
	fedora:dejavu-sans-fonts
)

pkg_install "${packages[@]}"
