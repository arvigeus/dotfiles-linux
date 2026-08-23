#!/usr/bin/env bash

_CHAOTIC_AUR_KEY=3056513887B78AEB
_CHAOTIC_AUR_KEYSERVER=keyserver.ubuntu.com
_CHAOTIC_AUR_BASE_URL=https://cdn-mirror.chaotic.cx/chaotic-aur

repo_enable() {
	if pkg_native_is_installed chaotic-keyring &&
		pkg_native_is_installed chaotic-mirrorlist &&
		grep -q '^\[chaotic-aur\]$' /etc/pacman.conf; then
		return
	fi

	if ! pacman-key --list-keys "$_CHAOTIC_AUR_KEY" >/dev/null 2>&1; then
		pacman-key --recv-key "$_CHAOTIC_AUR_KEY" \
			--keyserver "$_CHAOTIC_AUR_KEYSERVER"
	fi
	pacman-key --lsign-key "$_CHAOTIC_AUR_KEY"

	pacman -U --needed --noconfirm -- \
		"$_CHAOTIC_AUR_BASE_URL/chaotic-keyring.pkg.tar.zst" \
		"$_CHAOTIC_AUR_BASE_URL/chaotic-mirrorlist.pkg.tar.zst"

	if ! grep -q '^\[chaotic-aur\]$' /etc/pacman.conf; then
		cat >>/etc/pacman.conf <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
	fi
	pacman -Sy --noconfirm
}

repo_install() {
	repo_enable
	pkg_native_install "$@"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
