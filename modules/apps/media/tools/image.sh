#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	# image tooling
	# https://imagemagick.org
	arch:imagemagick
	fedora:ImageMagick
)

pkg_install "${packages[@]}"
