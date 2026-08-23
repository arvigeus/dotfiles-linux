#!/usr/bin/env bash
## Lutris game launcher
## https://lutris.net/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/net.lutris.Lutris
	flathub/runtime/org.freedesktop.Platform.VulkanLayer.gamescope/x86_64/23.08
	flathub/runtime/org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/23.08
)
pkg_install "${packages[@]}"
flatpak_alias lutris net.lutris.Lutris

github_download \
	"https://github.com/flightlessmango/MangoHud/blob/master/data/MangoHud.conf" \
	"$HOME/.var/app/net.lutris.Lutris/config/MangoHud/MangoHud.conf"
