#!/usr/bin/env bash

source "$SETUP_ROOT/lib/flatpak.sh"

source_prepare() {
	flatpak_prepare
	flatpak_remote_add flathub \
		https://dl.flathub.org/repo/flathub.flatpakrepo
}

source_install() {
	source_prepare
	flatpak_install flathub "$@"
}

source_is_installed() {
	command -v flatpak >/dev/null &&
		_flatpak_command info --system "$1" >/dev/null 2>&1
}

source_remove() {
	_flatpak_command uninstall --system -y --noninteractive "$@"
}
