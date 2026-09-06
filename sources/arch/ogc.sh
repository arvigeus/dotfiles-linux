#!/usr/bin/env bash

_OGC_KEY=F79100EF8C802DAB81C323BB8EEA5962FE510E19
_OGC_SERVER=https://pacman.opengamingcollective.org

source_prepare() {
	local refresh=false

	if ! pacman-key --list-keys "$_OGC_KEY" >/dev/null 2>&1; then
		pacman-key --recv-keys "$_OGC_KEY"
		pacman-key --lsign-key "$_OGC_KEY"
		refresh=true
	fi

	# OGC must precede Chaotic-AUR so a future overlapping OGC package keeps its
	# intended source. Both remain below Arch's official repositories.
	if pacman_repo_write ogc chaotic-aur <<EOF
Server = $_OGC_SERVER
EOF
	then
		refresh=true
	fi
	[[ $refresh == false ]] || pacman -Sy --noconfirm
}

source_install() {
	source_prepare
	local package packages=()
	for package in "$@"; do
		packages+=("ogc/$package")
	done
	pkg_native_install "${packages[@]}"
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
