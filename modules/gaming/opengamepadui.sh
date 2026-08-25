#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:aur/opengamepadui-bin
	fedora:terra/opengamepadui
)
pkg_install "${packages[@]}"
