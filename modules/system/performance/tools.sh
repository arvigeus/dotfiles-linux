#!/usr/bin/env bash
## Performance measuring tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	btop
	arch:drm-info
	fedora:drm_info
	lm_sensors
	pciutils
	psmisc
	powertop
	stress-ng
	libva-utils
	vulkan-tools
)

pkg_install "${packages[@]}"
