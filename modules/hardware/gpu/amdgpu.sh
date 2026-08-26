#!/usr/bin/env bash
## AMD GPU Mesa/Vulkan userspace
## https://wiki.archlinux.org/title/AMDGPU
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

pci_vendor_present 0x1002 || exit 0

packages=(
	radeontop
	nvtop
	arch:mesa
	arch:lib32-mesa
	arch:vulkan-radeon
	arch:lib32-vulkan-radeon
	arch:vulkan-icd-loader
	arch:lib32-vulkan-icd-loader
	arch:vulkan-mesa-layers
	arch:lib32-vulkan-mesa-layers
	fedora:mesa-libGL
	fedora:mesa-dri-drivers
	fedora:mesa-vulkan-drivers
	fedora:vulkan-loader
	fedora:mesa-libGL.i686
	fedora:mesa-dri-drivers.i686
	fedora:mesa-vulkan-drivers.i686
	fedora:vulkan-loader.i686
)
pkg_install "${packages[@]}"

# ROCm remains opt-in: Vulkan covers the original local-inference use case and
# ROCm support depends on the exact GPU generation.
