#!/usr/bin/env bash

source_prepare() {
	rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1 && return 0
	dnf -y install \
		"https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
		"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}

source_install() {
	source_prepare
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

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
