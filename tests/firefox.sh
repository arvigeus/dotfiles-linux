#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

# Missing package data must fail before writing any configuration.
for distro in arch fedora; do
	manager=pacman
	[[ $distro != fedora ]] || manager=dnf
	if env SETUP_ROOT="$PROJECT_ROOT" DISTRO="$distro" PACKAGE_MANAGER="$manager" PROJECT_ID=system \
		MODULE_DIR="$PROJECT_ROOT/modules/browsers" MODULE_PHASE=apply \
		HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/home/.config" \
		ARKENFOX_TEMPLATE="$TEST_ROOT/missing.js" bash "$PROJECT_ROOT/modules/browsers/firefox.sh" \
		>"$TEST_ROOT/output" 2>&1; then
		printf 'Firefox accepted a missing Arkenfox template\n' >&2
		exit 1
	fi
	rg -q 'Arkenfox template missing or empty:' "$TEST_ROOT/output"
done
[[ ! -e $TEST_ROOT/home ]]

export SETUP_ROOT="$PROJECT_ROOT" DISTRO=arch PACKAGE_MANAGER=pacman PROJECT_ID=system
export MODULE_DIR="$PROJECT_ROOT/modules/browsers" MODULE_PHASE=plan MODULE_PLAN_FILE="$TEST_ROOT/plan"
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/home/.config"
[[ -z ${FIREFOX_TEST_INSTALL_DIR:-} || $FIREFOX_TEST_INSTALL_DIR == /tmp/* ]]
export FIREFOX_INSTALL_DIR="${FIREFOX_TEST_INSTALL_DIR:-$TEST_ROOT/firefox}"
export ARKENFOX_TEMPLATE="$TEST_ROOT/user.js"
[[ -z ${ARKENFOX_TEST_TEMPLATE:-} ]] || cat "$ARKENFOX_TEST_TEMPLATE" >"$ARKENFOX_TEMPLATE"
printf 'user_pref("test.arkenfox.applied", true);\n' >>"$ARKENFOX_TEMPLATE"
# shellcheck source=modules/browsers/firefox.sh
source "$PROJECT_ROOT/modules/browsers/firefox.sh"
rg -q '^package\s+arch:aur/arkenfox-user.js$' "$MODULE_PLAN_FILE"
rg -q '^package\s+fedora:rpmspec/arkenfox-user.js$' "$MODULE_PLAN_FILE"
if rg -q 'arch:pkgbuild/arkenfox|crudini' "$MODULE_PLAN_FILE"; then
	exit 1
fi
if [[ -z ${FIREFOX_TEST_INSTALL_DIR:-} ]]; then
	mkdir -p "$FIREFOX_INSTALL_DIR"
	printf '#!/bin/sh\nexit 0\n' >"$FIREFOX_INSTALL_DIR/firefox"
	chmod +x "$FIREFOX_INSTALL_DIR/firefox"
fi
# Confine module writes and skip root ownership in the test fixture.
file_write() {
	[[ $1 == "$FIREFOX_INSTALL_DIR/"* ]]
	mkdir -p "$(dirname -- "$1")"
	cat >"$1"
}
module_apply
module_healthcheck
[[ ! -e $HOME ]]
rg -q '^var user_pref = pref;$' "$FIREFOX_INSTALL_DIR/arkenfox.cfg"
rg -q 'user_pref\("signon.rememberSignons", false\)' "$FIREFOX_INSTALL_DIR/arkenfox.cfg"
for distro in arch fedora; do
	DISTRO=$distro firefox_policies "$BROWSERS_CONFIG" >"$TEST_ROOT/$distro-policies.json"
	jq -e --arg distro "$distro" '
		.policies | (.Extensions.Install | length > 0) and
		(.SearchEngines.Add | any(.Alias == "@qwant")) and
		(.SearchEngines.Add | any(.Alias == (if $distro == "arch" then "@arch" else "@fedora" end)))
	' "$TEST_ROOT/$distro-policies.json" >/dev/null
done

# Optional real-browser consumption check in a disposable installation, never
# the user's Firefox. Firefox creates and selects its own profile normally.
if [[ -n ${FIREFOX_TEST_INSTALL_DIR:-} ]]; then
	policies="$FIREFOX_INSTALL_DIR/distribution/policies.json"
	jq '.policies.Extensions.Install = []' "$policies" >"$TEST_ROOT/policies.json"
	cp "$TEST_ROOT/policies.json" "$policies"
	timeout 90 "$FIREFOX_INSTALL_DIR/firefox" --headless --screenshot "$TEST_ROOT/firefox.png" about:blank
	[[ -s $TEST_ROOT/firefox.png ]]
	preferences=$(rg --hidden -l 'user_pref\("test.arkenfox.applied", true\)' "$HOME" -g prefs.js)
	[[ -n $preferences ]]
	rg -q 'user_pref\("signon.rememberSignons", false\)' "$preferences"
	rg -q 'user_pref\("browser.startup.page", 3\)' "$preferences"
	if [[ -n ${ARKENFOX_TEST_TEMPLATE:-} ]]; then
		rg -q 'user_pref\("network.http.referer.XOriginTrimmingPolicy", 2\)' "$preferences"
	fi
	# Native alternate profiles also receive configuration without a wrapper.
	alternate="$TEST_ROOT/alternate"
	mkdir -p "$alternate"
	timeout 90 "$FIREFOX_INSTALL_DIR/firefox" --headless --profile "$alternate" \
		--screenshot "$TEST_ROOT/alternate.png" about:blank
	[[ -s $TEST_ROOT/alternate.png && ! -e $alternate/user.js ]]
	rg -q 'user_pref\("test.arkenfox.applied", true\)' "$alternate/prefs.js"
	rg -q 'user_pref\("signon.rememberSignons", false\)' "$alternate/prefs.js"
fi
printf 'Firefox AutoConfig and native policies: ok\n'
