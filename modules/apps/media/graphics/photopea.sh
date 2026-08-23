#!/usr/bin/env bash
## Photopea — online photo editor
## https://www.photopea.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/webapp.sh"

pkg_install chromium
webapp_install \
	Photopea \
	https://www.photopea.com/ \
	photopea \
	'Graphics;RasterGraphics;Photography;'
