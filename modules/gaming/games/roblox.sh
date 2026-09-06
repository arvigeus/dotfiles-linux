#!/usr/bin/env bash
## Roblox through Sober
## https://www.roblox.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.vinegarhq.Sober
)

module_apply() {
	flatpak_alias roblox org.vinegarhq.Sober
	flatpak_override --device=input org.vinegarhq.Sober
}

module_entrypoint "$@"
