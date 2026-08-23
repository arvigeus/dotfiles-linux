#!/usr/bin/env bash
## Network lookup and troubleshooting tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	whois
    # Provides dig, host, nslookup
    fedora:bind-utils
    arch:bind
)
pkg_install "${packages[@]}"
