#!/usr/bin/env bash
## Wine and Windows app compatibility
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	flathub/com.usebottles.bottles
)
pkg_install "${packages[@]}"
