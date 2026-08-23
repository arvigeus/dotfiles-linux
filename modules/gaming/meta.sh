#!/usr/bin/env bash
## Archive utilities — 7z, rar, zip
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	aur/proton-cachyos-slr
    aur/wine-cachyos-opt
)

pkg_install "${packages[@]}"


paru -S 

git clone https://github.com/CachyOS/CachyOS-PKGBUILDS.git
cd CachyOS-PKGBUILDS/cachyos-gaming-meta
makepkg -si