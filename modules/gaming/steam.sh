#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	arch:multilib/steam
	fedora:rpmfusion/steam
)
pkg_install "${packages[@]}"
