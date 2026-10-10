#!/usr/bin/env bash

source_prepare() {
	# A source may have enabled Chaotic-AUR/OGC before this plugin runs. Keep
	# official 32-bit dependencies ahead of their alternative providers.
	local before
	before=$(awk '/^\[(ogc|chaotic-aur)\]$/ {
		print substr($0, 2, length($0) - 2); exit
	}' "${PACMAN_CONFIG:-/etc/pacman.conf}")
	if pacman_repo_write multilib "$before" <<'EOF'
Include = /etc/pacman.d/mirrorlist
EOF
	then
		pacman -Syu --needed --noconfirm
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
