#!/usr/bin/env bash
# FlatPark applications; their runtimes are resolved through Flathub.
# https://flatpark.org/setup

source "$SETUP_ROOT/lib/flatpak.sh"

repo_enable() {
	flatpak_prepare
	pkg_repo_enable flathub
	flatpak_remote_add flatpark \
		https://dl.flatpark.org/flatpark.flatpakrepo
}

repo_install() {
	repo_enable
	flatpak_install flatpark "$@"
}

repo_is_installed() {
	command -v flatpak >/dev/null &&
		flatpak info --system "$1" >/dev/null 2>&1
}
