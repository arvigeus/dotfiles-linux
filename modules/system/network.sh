#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

preserve_path /etc/NetworkManager/system-connections

pkg_install networkmanager
systemctl enable NetworkManager.service
