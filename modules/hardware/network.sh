#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
    networkmanager

    # Network lookup and troubleshooting tools
	whois
    # Provides dig, host, nslookup
    fedora:bind-utils
    arch:bind
)
pkg_install networkmanager
systemctl enable NetworkManager.service

preserve_path /etc/NetworkManager/system-connections
