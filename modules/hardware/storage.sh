#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
    udisks2
)

pkg_install "${packages[@]}"
systemctl enable fstrim.timer
