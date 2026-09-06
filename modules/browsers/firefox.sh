#!/usr/bin/env bash
## Firefox
## https://www.firefox.com
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/json.sh"
source "$SETUP_ROOT/lib/browsers.sh"

packages=(
	firefox jq util-linux unzip curl
	arch:aur/crudini
	fedora:crudini
	arch:pkgbuild/arkenfox-user.js
	fedora:rpmspec/arkenfox-user.js
)

module_apply() {
	BROWSERS_CONFIG=$(json_strip_comments "$MODULE_DIR/common.jsonc")

	# Arkenfox owns the base user.js. These are this profile's local overrides;
	# keep them separate so an Arkenfox update cannot discard local choices.
	# shellcheck disable=SC2034 # read via nameref in gecko_generate_userjs
	declare -A USER_PREFS=(
		# Enable restoring previous session
		["browser.startup.page"]=3
		["browser.sessionstore.enabled"]=true
		["browser.sessionstore.privacy_level"]=0

		# Use native XDG file picker
		["widget.use-xdg-desktop-portal.file-picker"]=1

		# Allow any search engine in about:preferences#search (https://superuser.com/a/1756774/204761)
		["browser.urlbar.update2.engineAliasRefresh"]=true

		["dom.webgpu.enabled"]=true
		["signon.rememberSignons"]=false # Already using BitWarden for that

		# Right-click on sites that disable it: hold Shift while right-clicking.
		# To always open Firefox's context menu (no Shift needed):
		# ["dom.event.contextmenu.enabled]=false
		# With the default true, this controls whether Shift+right-click suppresses
		# the page handler:
		["dom.event.contextmenu.shift_suppresses_event"]=true
	)

	FF_DIR="$XDG_CONFIG_HOME/mozilla/firefox"
	PROFILE="$FF_DIR/default"
	if [[ -d /usr/lib64/firefox/browser/extensions ]]; then
		FF_SYSTEM_EXT_DIR=/usr/lib64/firefox/browser/extensions
	else
		FF_SYSTEM_EXT_DIR=/usr/lib/firefox/browser/extensions
	fi

	gecko_profiles_ini | file_write "$FF_DIR/profiles.ini"
	gecko_generate_userjs USER_PREFS | file_write "$PROFILE/user-overrides.js"
	{
		cat /usr/share/arkenfox/user.js
		printf '\n'
		cat "$PROFILE/user-overrides.js"
	} | file_write "$PROFILE/user.js"

	firefox_install_search_engines "$BROWSERS_CONFIG" "$PROFILE"
	firefox_install_extensions "$BROWSERS_CONFIG" "$FF_SYSTEM_EXT_DIR"
}

module_entrypoint "$@"
