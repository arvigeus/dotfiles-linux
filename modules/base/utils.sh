#!/usr/bin/env bash
## Small baseline command-line utilities
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	bc
	less
	rsync
	wget
)

pkg_install "${packages[@]}"
