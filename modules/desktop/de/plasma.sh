#!/usr/bin/env bash
## Minimal KDE Plasma desktop
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	plasma-desktop
	plasma-workspace
	plasma-nm
	plasma-pa
	bluedevil
	powerdevil
	kscreen
	dolphin
	konsole
	xdg-desktop-portal-kde

	arch:systemsettings
	fedora:plasma-systemsettings

	plasma-login-manager
	fedora:kcm-plasmalogin
)

pkg_install "${packages[@]}"
systemctl enable plasmalogin.service
