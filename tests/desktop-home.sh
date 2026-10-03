#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/old/.config/hypr" "$TEST_ROOT/new" "$TEST_ROOT/home"
printf 'dofile("/usr/share/zephyrus-shell/hyprland/hyprland.lua")\n' >"$TEST_ROOT/old/.config/hypr/hyprland.lua"
printf 'obsolete\n' >"$TEST_ROOT/old/.config/obsolete.conf"
cp -a "$TEST_ROOT/old/." "$TEST_ROOT/home/"
printf '.config/hypr/hyprland.lua\treplace\tnever\n' >"$TEST_ROOT/old-policy"
PROJECT_ID=system bash "$PROJECT_ROOT/installer/reconcile/home.sh" \
	"$TEST_ROOT/old" "$TEST_ROOT/new" "$TEST_ROOT/home" \
	"$TEST_ROOT/old-policy" /nonexistent "$(id -u)" "$(id -g)" >/dev/null
[[ -s $TEST_ROOT/home/.config/hypr/hyprland.lua ]]
[[ ! -e $TEST_ROOT/home/.config/obsolete.conf ]]
printf 'desktop fallback home configuration: ok\n'
