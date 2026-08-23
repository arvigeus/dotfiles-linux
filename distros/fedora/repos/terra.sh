#!/usr/bin/env bash

repo_enable() {
	pkg_native_is_installed terra-release && return 0
	pkg_native_install dnf5-plugins
	dnf -y install --nogpgcheck \
		--repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
		terra-release
}

repo_install() {
	repo_enable
	pkg_native_install "$@"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
