#!/usr/bin/env bash
## Shared text/input dependencies for desktop and gaming sessions
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	# Vanilla distro gaming stack.
	ibus
	arch:noto-fonts
	arch:ttf-dejavu
	fedora:google-noto-sans-fonts
	fedora:dejavu-sans-fonts
)

pkg_install "${packages[@]}"
