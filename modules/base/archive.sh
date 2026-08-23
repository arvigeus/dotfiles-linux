#!/usr/bin/env bash
## Archive utilities — 7z, rar, zip
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:unrar
	fedora:rpmfusion/unrar
	unzip
	7zip
)

pkg_install "${packages[@]}"
