#!/usr/bin/env bash

repo_enable() {
    if ! grep -q '^\[multilib\]$' /etc/pacman.conf; then
	sed -i \
		'/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' \
		/etc/pacman.conf
	pacman -Sy --noconfirm
    fi
}

repo_install() {
	repo_enable
	local package packages=()
	for package in "$@"; do
		packages+=("$package")
	done
	pkg_native_install "${packages[@]}"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
