#!/usr/bin/env bash
## Distrobox — run any Linux distribution inside your terminal via podman
## https://distrobox.it/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	distrobox
	flathub/io.github.dvlv.boxbuddyrs
)

module_apply() {
	flatpak_alias boxbuddy io.github.dvlv.boxbuddyrs
}

module_entrypoint "$@"
