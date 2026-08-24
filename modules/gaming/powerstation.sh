#!/usr/bin/env bash

packages=(
	arch:local-aur/powerstation-bin
	fedora:terra/powerstation
)

pkg_install "${packages[@]}"

# Follow Bazzite's non-handheld PowerStation policy.
systemctl disable powerstation.service
