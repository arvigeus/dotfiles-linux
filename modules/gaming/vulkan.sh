#!/usr/bin/env bash

packages=(
	vkbasalt
	arch:lib32-vkbasalt
	fedora:vkBasalt.i686

	arch:aur/vulkan-low-latency-layer
	fedora:terra/vulkan-low-latency-layer
)

pkg_install "${packages[@]}"
