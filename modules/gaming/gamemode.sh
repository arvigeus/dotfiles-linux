#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	gamemode
	arch:lib32-gamemode
	fedora:gamemode.i686
)
pkg_install "${packages[@]}"
