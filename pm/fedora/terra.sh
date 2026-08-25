#!/usr/bin/env bash

pm_enable() {
	pkg_native_is_installed terra-release && return 0
	pkg_native_install dnf5-plugins
	dnf -y install --nogpgcheck \
		--repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
		terra-release
}

pm_install() {
	pm_enable
	dnf -y install --from-repo=terra "$@"
}

pm_is_installed() {
	pkg_native_is_installed "$1"
}

pm_remove() {
	pkg_native_remove "$@"
}
