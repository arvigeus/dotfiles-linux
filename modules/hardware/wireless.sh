#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	wireless-regdb # Wireless regulatory database and radio tooling
	wavemon
)

pkg_install "${packages[@]}"
