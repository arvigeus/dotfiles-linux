#!/usr/bin/env bash
## https://github.com/bluez
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	bluez
	arch:bluez-utils
)

pkg_install "${packages[@]}"
systemctl enable bluetooth.service

preserve_path /var/lib/bluetooth
