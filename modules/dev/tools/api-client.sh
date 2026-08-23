#!/usr/bin/env bash
## Yaak API client
## https://yaak.app/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flatpark/app.yaak.Yaak
)
pkg_install "${packages[@]}"
flatpak_alias yaak app.yaak.Yaak
