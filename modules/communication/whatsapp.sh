#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	## https://github.com/rafatosta/zapzap
	flathub/com.rtosta.zapzap
	#flathub/com.ktechpit.whatsie
)
module_apply() {
	flatpak_alias zapzap com.rtosta.zapzap
}

module_entrypoint "$@"
