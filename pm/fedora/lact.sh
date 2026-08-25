#!/usr/bin/env bash

pm_enable() {
	grep -Rqs 'ilyaz/LACT' /etc/yum.repos.d && return 0
	pkg_native_install dnf5-plugins
	dnf -y copr enable ilyaz/LACT
}

pm_install() {
	pm_enable
	dnf -y install \
		--from-repo='copr:copr.fedorainfracloud.org:ilyaz:LACT' \
		"$@"
}

pm_is_installed() {
	pkg_native_is_installed "$1"
}

pm_remove() {
	pkg_native_remove "$@"
}
