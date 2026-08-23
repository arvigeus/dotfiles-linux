#!/usr/bin/env bash

_AUR_BUILD_USER=dotfiles-aur

repo_enable() {
	pkg_native_install base-devel git sudo
	pkg_install chaotic-aur/paru

	if ! id "$_AUR_BUILD_USER" >/dev/null 2>&1; then
		useradd --create-home "$_AUR_BUILD_USER"
	fi
	local sudoers="/etc/sudoers.d/$_AUR_BUILD_USER"
	printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$_AUR_BUILD_USER" >"$sudoers"
	chmod 0440 "$sudoers"
}

repo_install() {
	repo_enable
	sudo -u "$_AUR_BUILD_USER" paru --noconfirm --needed --skipreview -S -- "$@"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
