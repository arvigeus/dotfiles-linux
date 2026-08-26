#!/usr/bin/env bash
## AMD Ryzen microcode and inspection tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

cpu_vendor_is AuthenticAMD || exit 0

packages=(
	arch:amd-ucode
	fedora:amd-ucode-firmware

	# Tools
	arch:cpupower
	fedora:kernel-tools
)
pkg_install "${packages[@]}"
