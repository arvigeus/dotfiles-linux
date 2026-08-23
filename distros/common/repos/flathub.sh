#!/usr/bin/env bash

source "$SETUP_ROOT/lib/flatpak.sh"

repo_enable() {
	flatpak_prepare
	flatpak_remote_add flathub \
		https://dl.flathub.org/repo/flathub.flatpakrepo
}

repo_install() {
	repo_enable
	flatpak_install flathub "$@"
}

repo_is_installed() {
	command -v flatpak >/dev/null &&
		flatpak info --system "$1" >/dev/null 2>&1
}
