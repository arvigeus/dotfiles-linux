#!/usr/bin/env bash
## Chromium and Chrome-compatible browser setup
## https://www.chromium.org/Home/
## https://www.google.com/chrome/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/json.sh"
source "$SETUP_ROOT/lib/browsers.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	chromium jq
	flathub/com.google.Chrome
)

pkg_install "${packages[@]}"
flatpak_alias chrome com.google.Chrome
BROWSERS_CONFIG=$(json_strip_comments "$MODULE_DIR/common.jsonc")

setup_chromium() {
	chromium_install_extensions "$BROWSERS_CONFIG"
	# Keep Chrome clean
}

setup_chromium
