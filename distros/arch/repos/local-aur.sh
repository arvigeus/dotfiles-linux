#!/usr/bin/env bash

# Tracked PKGBUILDs are an explicit fallback, not an implicit AUR override.
# shellcheck source=distros/arch/repos/_aur-build.sh
source "${BASH_SOURCE[0]%/*}/_aur-build.sh"

repo_enable() {
	_aur_build_setup
}

repo_install() {
	repo_enable

	local package recipe build_directory
	for package in "$@"; do
		recipe="$SETUP_ROOT/distros/arch/aur/$package"
		[[ -f $recipe/PKGBUILD ]] || {
			printf 'No tracked PKGBUILD for %s\n' "$package" >&2
			return 1
		}
		build_directory=$(mktemp -d /tmp/dotfiles-local-aur.XXXXXX)
		cp -a -- "$recipe/." "$build_directory/"
		chown -R "$_AUR_BUILD_USER:$_AUR_BUILD_USER" "$build_directory"
		_aur_makepkg "$build_directory"
		rm -rf -- "$build_directory"
	done
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
