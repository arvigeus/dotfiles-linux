#!/usr/bin/env bash

repo_enable() {
	pkg_native_install dnf5-plugins
	dnf -y copr enable ilyaz/LACT
}

repo_install() {
	repo_enable
	pkg_native_install "$@"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
