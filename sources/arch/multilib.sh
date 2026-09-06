#!/usr/bin/env bash

source_prepare() {
	if pacman_repo_write multilib <<'EOF'
Include = /etc/pacman.d/mirrorlist
EOF
	then
		pacman -Sy --noconfirm
	fi
}

source_install() {
	source_prepare
	local package packages=()
	for package in "$@"; do
		packages+=("multilib/$package")
	done
	pkg_native_install "${packages[@]}"
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
