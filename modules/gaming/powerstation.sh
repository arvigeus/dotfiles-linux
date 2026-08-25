#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	arch:pkgbuild/powerstation-bin
	fedora:terra/powerstation
)

pkg_install "${packages[@]}"

# Follow Bazzite's non-handheld PowerStation policy.
systemctl disable powerstation.service
