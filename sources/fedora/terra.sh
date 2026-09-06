#!/usr/bin/env bash

source_prepare() {
	pkg_native_is_installed terra-release && return 0
	pkg_native_install dnf5-plugins
	dnf -y install --nogpgcheck \
		--repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
		terra-release
}

source_install() {
	source_prepare
	dnf -y install --from-repo=terra "$@"
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
