#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	# https://www.thunderbird.net
	flathub/org.mozilla.Thunderbird
	# io.github.alainm23.planify
	# org.gnome.World.Iotas
)

module_apply() {
	flatpak_alias thunderbird org.mozilla.Thunderbird
}

module_entrypoint "$@"
