#!/usr/bin/env bash
## Heroic Games Launcher
## https://heroicgameslauncher.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/com.heroicgameslauncher.hgl
)

module_apply() {
	flatpak_alias heroic com.heroicgameslauncher.hgl
}

module_entrypoint "$@"
