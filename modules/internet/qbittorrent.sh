#!/usr/bin/env bash
## qBittorrent
## https://www.qbittorrent.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.qbittorrent.qBittorrent
)
module_apply() {
	flatpak_alias qbittorrent org.qbittorrent.qBittorrent
}

module_entrypoint "$@"

## Tricks and tips:
## Remove lockfile: rm ~/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent/ipc-socket ~/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent/lockfile
