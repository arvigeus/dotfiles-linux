#!/usr/bin/env bash

pm_enable() {
	grep -Rqs 'bazzite-org/bazzite' /etc/yum.repos.d && return 0
	pkg_native_install dnf5-plugins
	dnf -y copr enable bazzite-org/bazzite
}

pm_install() {
	pm_enable
	dnf -y install \
		--from-repo='copr:copr.fedorainfracloud.org:bazzite-org:bazzite' \
		"$@"
}

pm_is_installed() {
	pkg_native_is_installed "$1"
}

pm_remove() {
	pkg_native_remove "$@"
}
