#!/usr/bin/env bash
## NetHack 3D web client
## https://github.com/JamesIV4/nethack-3d
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/webapp.sh"

pkg_install chromium
webapp_install \
	'NetHack 3D' \
	https://jamesiv4.github.io/nethack-3d/ \
	nethack \
	'Game;RolePlaying;'
