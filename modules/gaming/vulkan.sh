#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	arch:vkbasalt
	fedora:vkBasalt
	arch:lib32-vkbasalt
	fedora:vkBasalt.i686

	arch:aur/vulkan-low-latency-layer
	fedora:terra/vulkan-low-latency-layer
)

pkg_install "${packages[@]}"
