#!/usr/bin/env bash

_AUR_USER=system-aur
_AUR_HOME=/var/lib/$PROJECT_ID/aur

source_prepare() {
	pkg_install base-devel git sudo arch:chaotic-aur/paru
	install -d -m 0755 "/var/lib/$PROJECT_ID"
	if ! id "$_AUR_USER" >/dev/null 2>&1; then
		useradd --system --create-home --home-dir "$_AUR_HOME" \
			--shell /usr/bin/nologin "$_AUR_USER"
	fi
	local sudoers="/etc/sudoers.d/$_AUR_USER"
	printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$_AUR_USER" >"$sudoers"
	chmod 0440 "$sudoers"
}

source_install() {
	source_prepare

	local package
	for package in "$@"; do
		[[ $package =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$ ]] || {
			printf 'Invalid AUR package name: %s\n' "$package" >&2
			return 1
		}
		sudo --user "$_AUR_USER" \
			env HOME="$_AUR_HOME" \
			paru --aur --noconfirm --needed --skipreview -S -- "$package"
	done
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
