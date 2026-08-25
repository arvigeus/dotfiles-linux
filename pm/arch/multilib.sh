#!/usr/bin/env bash

pm_enable() {
	if pacman_repo_write multilib <<'EOF'
Include = /etc/pacman.d/mirrorlist
EOF
	then
		pacman -Sy --noconfirm
	fi
}

pm_install() {
	pm_enable
	local package packages=()
	for package in "$@"; do
		packages+=("multilib/$package")
	done
	pkg_native_install "${packages[@]}"
}

pm_is_installed() {
	pkg_native_is_installed "$1"
}

pm_remove() {
	pkg_native_remove "$@"
}
