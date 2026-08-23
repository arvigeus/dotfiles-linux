#!/usr/bin/env bash
## UMU Launcher — run Windows games through Proton outside Steam
## https://github.com/Open-Wine-Components/umu-launcher
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:umu-launcher
	fedora:bazzite/umu-launcher
)

pkg_install "${packages[@]}"
