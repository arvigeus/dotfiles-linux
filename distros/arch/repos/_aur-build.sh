#!/usr/bin/env bash

_AUR_BUILD_USER=dotfiles-aur
_AUR_BUILD_HOME=/home/$_AUR_BUILD_USER

_aur_makepkg() {
	local directory=${1:?A build directory is required}
	sudo --user "$_AUR_BUILD_USER" \
		env HOME="$_AUR_BUILD_HOME" \
		bash -c 'cd -- "$1" && exec makepkg --noconfirm --needed --syncdeps --install --cleanbuild --clean' \
		bash "$directory"
}

_aur_build_setup() {
	pkg_repo_enable chaotic-aur
	pkg_native_install base-devel git sudo chaotic-aur/paru

	if ! id "$_AUR_BUILD_USER" >/dev/null 2>&1; then
		useradd --create-home --shell /usr/bin/nologin "$_AUR_BUILD_USER"
	fi
	local sudoers="/etc/sudoers.d/$_AUR_BUILD_USER"
	printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$_AUR_BUILD_USER" >"$sudoers"
	chmod 0440 "$sudoers"
}
