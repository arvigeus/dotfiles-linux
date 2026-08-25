#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"


packages=(
	arch:pkgbuild/steamos-manager-powerstation
	fedora:terra/steamos-manager-powerstation
)

pkg_install "${packages[@]}"

# SteamOS Manager has root and per-session daemons. Its current session-control
# implementation is SDDM-specific, so the API remains unavailable: no SteamOS
# autologin marker is installed and Plasma Login Manager stays in charge of
# choosing Plasma or either gaming session.
systemctl enable steamos-manager.service

systemctl --global enable \
	steamos-manager.service \
	steamos-manager-session-cleanup.service
