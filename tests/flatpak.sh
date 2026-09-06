#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SETUP_ROOT=$PROJECT_ROOT
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

source "$PROJECT_ROOT/lib/flatpak.sh"
_FLATPAK_HOME_PARENT=$TEST_ROOT

flatpak() {
	[[ $HOME == "$TEST_ROOT"/.system-flatpak.* ]]
	[[ $XDG_CONFIG_HOME == "$HOME/.config" ]]
	[[ $XDG_DATA_HOME == "$HOME/.local/share" ]]
	[[ $XDG_STATE_HOME == "$HOME/.local/state" ]]
	[[ $XDG_CACHE_HOME == "$HOME/.cache" ]]
	[[ $* == 'info --system org.example.App' ||
		$* == 'override --system --device=input org.example.App' ]]
}

_flatpak_command info --system org.example.App
flatpak_override --device=input org.example.App
[[ -z $(find "$TEST_ROOT" -mindepth 1 -print -quit) ]] || {
	printf 'Flatpak temporary home was not removed\n' >&2
	exit 1
}

printf 'flatpak environment: ok\n'
