#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:networkmanager
	fedora:NetworkManager

	# Network lookup and troubleshooting tools
	whois
	# Provides dig, host, nslookup
	fedora:bind-utils
	arch:bind
)

module_apply() {
	systemctl enable NetworkManager.service

	preserve_path /etc/NetworkManager/system-connections
}

module_entrypoint "$@"
