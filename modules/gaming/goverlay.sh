#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	goverlay
)

pkg_install "${packages[@]}"
