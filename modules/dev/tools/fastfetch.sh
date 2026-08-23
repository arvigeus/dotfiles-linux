#!/usr/bin/env bash
## fastfetch — system information tool
## https://github.com/fastfetch-cli/fastfetch
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	fastfetch
)

pkg_install "${packages[@]}"
