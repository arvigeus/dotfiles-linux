#!/usr/bin/env bash

_OGC_KEY=F79100EF8C802DAB81C323BB8EEA5962FE510E19
_OGC_SERVER=https://pacman.opengamingcollective.org

repo_enable() {
	if ! pacman-key --list-keys "$_OGC_KEY" >/dev/null 2>&1; then
		pacman-key --recv-keys "$_OGC_KEY"
	fi
	pacman-key --lsign-key "$_OGC_KEY"

	if ! grep -q '^\[ogc\]$' /etc/pacman.conf; then
		# OGC must precede Chaotic-AUR so a future overlapping OGC package keeps
		# its intended source. Both remain below Arch's official repositories.
		if grep -q '^\[chaotic-aur\]$' /etc/pacman.conf; then
			sed -i \
				'/^\[chaotic-aur\]$/i [ogc]\
Server = https://pacman.opengamingcollective.org\
' /etc/pacman.conf
		else
			cat >>/etc/pacman.conf <<EOF

[ogc]
Server = $_OGC_SERVER
EOF
		fi
		pacman -Sy --noconfirm
	fi
}

repo_install() {
	repo_enable
	local package packages=()
	for package in "$@"; do
		packages+=("ogc/$package")
	done
	pkg_native_install "${packages[@]}"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
