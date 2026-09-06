#!/usr/bin/env bash
# FlatPark applications; their runtimes are resolved through Flathub.
# https://flatpark.org/setup

source "$SETUP_ROOT/lib/flatpak.sh"

source_prepare() {
	flatpak_prepare
	pkg_repo_enable flathub
	flatpak_remote_add flatpark \
		https://dl.flatpark.org/flatpark.flatpakrepo
}

source_install() {
	source_prepare
	flatpak_install flatpark "$@"
}

source_is_installed() {
	command -v flatpak >/dev/null &&
		_flatpak_command info --system "$1" >/dev/null 2>&1
}

source_remove() {
	_flatpak_command uninstall --system -y --noninteractive "$@"
}
