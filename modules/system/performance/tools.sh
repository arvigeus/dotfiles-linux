#!/usr/bin/env bash
## Performance measuring tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	btop
	powertop
	stress-ng
)

pkg_install "${packages[@]}"
