#!/usr/bin/env bash

pm_enable() {
	rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1 && return 0
	dnf -y install \
		"https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
		"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}

pm_install() {
	pm_enable
	local package
	for package in "$@"; do
		case $package in
		ffmpeg)
			dnf -y swap ffmpeg-free ffmpeg --allowerasing \
				--from-repo=rpmfusion-free,rpmfusion-free-updates
			;;
		@multimedia)
			dnf -y group install multimedia \
				--setopt=install_weak_deps=False \
				--exclude=PackageKit-gstreamer-plugin
			;;
		steam)
			dnf -y install \
				--from-repo=rpmfusion-nonfree,rpmfusion-nonfree-updates \
				"$package"
			;;
		*)
			dnf -y install \
				--from-repo=rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates \
				"$package"
			;;
		esac
	done
}

pm_is_installed() {
	pkg_native_is_installed "$1"
}

pm_remove() {
	pkg_native_remove "$@"
}
