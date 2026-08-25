#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	arch:aur/inputplumber-bin
	fedora:terra/inputplumber
)

pkg_install "${packages[@]}"

# InputPlumber is opt-in on this laptop, but its upstream DMI/udev rules can
# still start it on a supported handheld.
systemctl disable inputplumber.service
