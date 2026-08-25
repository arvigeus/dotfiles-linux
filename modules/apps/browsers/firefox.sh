#!/usr/bin/env bash
## Firefox
## https://www.firefox.com
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/json.sh"
source "$SETUP_ROOT/lib/browsers.sh"

packages=(
	firefox
	arch:aur/crudini
	fedora:crudini
)

BROWSERS_CONFIG=$(json_strip_comments "$MODULE_DIR/common.jsonc")

pkg_install "${packages[@]}"

# https://github.com/arkenfox/user.js/blob/master/user.js
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

	# Security
	["dom.security.https_only_mode"]=true
	["browser.contentblocking.category"]="strict"
	["security.ssl.require_safe_negotiation"]=true
	["security.cert_pinning.enforcement_level"]=2 # strict
	["browser.xul.error_pages.expert_bad_cert"]=true # display advanced information on Insecure Connection warning pages

	# Containers
	["privacy.userContext.enabled"]=true
	["privacy.userContext.ui.enabled"]=true

	# Misc
	["browser.aboutConfig.showWarning"]=false
	["dom.disable_window_move_resize"]=true # prevent scripts from moving and resizing open windows
	["browser.download.manager.addToRecentDocs"]=false
	["browser.startup.homepage_override.mstone"]="ignore" # disable welcome notices

	# Extensions
	["extensions.enabledScopes"]=5 # profile + application

	# Bloat
	["extensions.pocket.enabled"]=false
	["identity.fxaccounts.enabled"]=false
	["browser.newtabpage.activity-stream.showWeather"]=false
	["signon.rememberSignons"]=false # Already using BitWarden for that
	["browser.urlbar.suggest.trending"]=false
	["browser.newtabpage.activity-stream.showSponsoredTopSites"]=false
	["browser.newtabpage.activity-stream.showSponsoredCheckboxes"]=false
	["browser.newtabpage.activity-stream.default.sites"]="" # Clear default top sites

	# Disable recommendations
	["extensions.getAddons.showPane"]=false
	["extensions.htmlaboutaddons.recommendations.enabled"]=false
	["browser.discovery.enabled"]=false

	# Disable search suggestions
	["browser.urlbar.trending.featureGate"]=false
	["browser.urlbar.addons.featureGate"]=false
	["browser.urlbar.amp.featureGate"]=false
	["browser.urlbar.importantDates.featureGate"]=false
	["browser.urlbar.market.featureGate"]=false
	["browser.urlbar.mdn.featureGate"]=false
	["browser.urlbar.weather.featureGate"]=false
	["browser.urlbar.wikipedia.featureGate"]=false
	["browser.urlbar.yelp.featureGate"]=false
	["browser.urlbar.yelpRealtime.featureGate"]=false

	# Allow separate search for private mode
	["browser.search.separatePrivateDefault"]=true
	["browser.search.separatePrivateDefault.ui.enabled"]=true

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

setup_firefox() {
	firefox_install_search_engines "$BROWSERS_CONFIG" "$PROFILE"
	firefox_install_extensions "$BROWSERS_CONFIG" "$FF_SYSTEM_EXT_DIR"
}

gecko_profiles_ini | file_write "$FF_DIR/profiles.ini"
gecko_generate_userjs USER_PREFS | file_write "$PROFILE/user.js"

pkg_from_source setup_firefox jq util-linux unzip curl
