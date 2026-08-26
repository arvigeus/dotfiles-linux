#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	arch:multilib/steam
	fedora:rpmfusion/steam

	arch:multilib/steam-devices
	fedora:steam-devices
)
pkg_install "${packages[@]}"
