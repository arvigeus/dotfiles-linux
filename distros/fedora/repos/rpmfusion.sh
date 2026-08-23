#!/usr/bin/env bash

repo_enable() {
	rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1 && return 0
	dnf -y install \
		"https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
		"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}

repo_install() {
	repo_enable
	local package
	for package in "$@"; do
		case $package in
		ffmpeg)
			dnf -y swap ffmpeg-free ffmpeg --allowerasing
			;;
		@multimedia)
			dnf -y group install multimedia \
				--setopt=install_weak_deps=False \
				--exclude=PackageKit-gstreamer-plugin
			;;
		*) pkg_native_install "$package" ;;
		esac
	done
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
