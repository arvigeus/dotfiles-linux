#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
    ## https://github.com/rafatosta/zapzap
	flathub/com.rtosta.zapzap
    #flathub/com.ktechpit.whatsie
)
pkg_install "${packages[@]}"
flatpak_alias zapzap com.rtosta.zapzap
