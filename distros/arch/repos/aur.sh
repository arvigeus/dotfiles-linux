#!/usr/bin/env bash

# shellcheck source=distros/arch/repos/_aur-build.sh
source "${BASH_SOURCE[0]%/*}/_aur-build.sh"

repo_enable() {
	_aur_build_setup
}

repo_install() {
	repo_enable

	local package
	for package in "$@"; do
		sudo --user "$_AUR_BUILD_USER" \
			env HOME="$_AUR_BUILD_HOME" \
			paru --noconfirm --needed --skipreview -S -- "$package"
	done
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
