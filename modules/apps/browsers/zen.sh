#!/usr/bin/env bash
## Zen Browser
## https://zen-browser.app/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/json.sh"
source "$SETUP_ROOT/lib/browsers.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	jq util-linux unzip curl
	flathub/app.zen_browser.zen
	arch:aur/crudini
	fedora:crudini
)
pkg_install "${packages[@]}"
flatpak_alias zen-browser app.zen_browser.zen

BROWSERS_CONFIG=$(json_strip_comments "$MODULE_DIR/common.jsonc")
ZEN_HOME="$HOME/.var/app/app.zen_browser.zen/.zen"
PROFILE="$ZEN_HOME/default"
ZEN_EXT_DIR="$PROFILE/extensions"

setup_zen() {
	firefox_install_search_engines "$BROWSERS_CONFIG" "$PROFILE"
	firefox_install_extensions "$BROWSERS_CONFIG" "$ZEN_EXT_DIR"
}

gecko_profiles_ini | file_write "$ZEN_HOME/profiles.ini"
setup_zen
