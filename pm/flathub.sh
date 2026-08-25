#!/usr/bin/env bash

source "$SETUP_ROOT/lib/flatpak.sh"

pm_enable() {
	flatpak_prepare
	flatpak_remote_add flathub \
		https://dl.flathub.org/repo/flathub.flatpakrepo
}

pm_install() {
	pm_enable
	flatpak_install flathub "$@"
}

pm_is_installed() {
	command -v flatpak >/dev/null &&
		flatpak info --system "$1" >/dev/null 2>&1
}

pm_remove() {
	flatpak uninstall --system -y --noninteractive "$@"
}
