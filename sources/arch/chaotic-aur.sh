#!/usr/bin/env bash

_CHAOTIC_AUR_KEY=3056513887B78AEB
_CHAOTIC_AUR_KEYSERVER=keyserver.ubuntu.com
_CHAOTIC_AUR_BASE_URL=https://cdn-mirror.chaotic.cx/chaotic-aur

source_prepare() {
	local refresh=false

	if ! pkg_native_is_installed chaotic-keyring ||
		! pkg_native_is_installed chaotic-mirrorlist; then
		if ! pacman-key --list-keys "$_CHAOTIC_AUR_KEY" >/dev/null 2>&1; then
			pacman-key --recv-key "$_CHAOTIC_AUR_KEY" \
				--keyserver "$_CHAOTIC_AUR_KEYSERVER"
		fi
		pacman-key --lsign-key "$_CHAOTIC_AUR_KEY"

		pacman -U --needed --noconfirm -- \
			"$_CHAOTIC_AUR_BASE_URL/chaotic-keyring.pkg.tar.zst" \
			"$_CHAOTIC_AUR_BASE_URL/chaotic-mirrorlist.pkg.tar.zst"
		refresh=true
	fi

	if pacman_repo_write chaotic-aur <<'EOF'
Include = /etc/pacman.d/chaotic-mirrorlist
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
		packages+=("chaotic-aur/$package")
	done
	pkg_native_install "${packages[@]}"
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
