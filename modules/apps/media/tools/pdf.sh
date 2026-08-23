#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	# PDF conversion tooling
	# https://ghostscript.com/
	ghostscript
)

pkg_install "${packages[@]}"
