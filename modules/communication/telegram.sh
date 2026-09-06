#!/usr/bin/env bash
## Telegram desktop client
## https://telegram.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.telegram.desktop
)
module_apply() {
	flatpak_alias telegram org.telegram.desktop
}

module_entrypoint "$@"
