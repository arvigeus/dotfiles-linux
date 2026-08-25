#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	gamescope
)
pkg_install "${packages[@]}"
