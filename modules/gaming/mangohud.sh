#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	mangohud
	arch:lib32-mangohud
	fedora:mangohud.i686
)

pkg_install "${packages[@]}"
