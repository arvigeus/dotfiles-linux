#!/usr/bin/env bash

repo_enable() {
	grep -q '^\[g14\]' /etc/pacman.conf && return 0
	pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
	pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
	cat >>/etc/pacman.conf <<'EOF'

[g14]
Server = https://arch.asus-linux.org
EOF
	pacman -Sy --noconfirm
}

repo_install() {
	repo_enable
	pkg_native_install "$@"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
