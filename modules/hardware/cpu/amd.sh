#!/usr/bin/env bash
## AMD Ryzen microcode and inspection tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

module_check() {
	cpu_vendor_is AuthenticAMD
}

packages=(
	arch:amd-ucode
	fedora:amd-ucode-firmware

	# Tools
	arch:cpupower
	fedora:kernel-tools
)

module_entrypoint "$@"
