#!/usr/bin/env bash
## AMD Ryzen power tuning
## https://github.com/FlyGoat/RyzenAdj
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

cpu_vendor_is AuthenticAMD || exit 0

packages=(
	arch:amd-ucode
	fedora:amd-ucode-firmware
	fedora:bazzite/ryzenadj

	# Tools
	arch:cpupower
	fedora:kernel-tools
)
pkg_install "${packages[@]}"

# RyzenAdj uses /dev/mem on supported hardware. Tuning is intentionally left to
# the booted administrator; provisioning never changes live power limits.
