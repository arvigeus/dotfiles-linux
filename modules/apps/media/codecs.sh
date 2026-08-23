#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

if [[ "$DISTRO" == "fedora" ]]; then
    # Fedora multimedia codecs from RPM Fusion
	# https://rpmfusion.org/Howto/Multimedia
	dnf swap -y ffmpeg-free ffmpeg --allowerasing
	dnf group install -y multimedia \
		--setopt="install_weak_deps=False" \
		--exclude=PackageKit-gstreamer-plugin
fi
