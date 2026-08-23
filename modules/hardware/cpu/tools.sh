#!/usr/bin/env bash
## CPU frequency and governor control
## https://wiki.archlinux.org/title/CPU_frequency_scaling
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

cpu_vendor_is AuthenticAMD || exit 0

packages=(
	arch:cpupower
	fedora:kernel-tools
)
pkg_install "${packages[@]}"
