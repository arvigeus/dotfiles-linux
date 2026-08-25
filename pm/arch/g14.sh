#!/usr/bin/env bash

pm_enable() {
	local key=8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 refresh=false
	if ! pacman-key --list-keys "$key" >/dev/null 2>&1; then
		pacman-key --recv-keys "$key"
		refresh=true
	fi
	pacman-key --lsign-key "$key"
	if pacman_repo_write g14 <<'EOF'
Server = https://arch.asus-linux.org
EOF
	then
		refresh=true
	fi
	[[ $refresh == false ]] || pacman -Sy --noconfirm
}

pm_install() {
	pm_enable
	local package packages=()
	for package in "$@"; do
		packages+=("g14/$package")
	done
	pkg_native_install "${packages[@]}"
}

pm_is_installed() {
	pkg_native_is_installed "$1"
}

pm_remove() {
	pkg_native_remove "$@"
}
