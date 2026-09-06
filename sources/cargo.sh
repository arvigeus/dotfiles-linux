#!/usr/bin/env bash

readonly CARGO_INSTALL_ROOT=/usr/local

source_prepare() {
	pkg_is_installed cargo || pkg_install cargo
	pkg_is_installed gcc || pkg_install gcc
}

source_install() {
	source_prepare
	local crate
	for crate in "$@"; do
		cargo install --locked --root "$CARGO_INSTALL_ROOT" "$crate"
	done
}

source_remove() {
	local crate
	for crate in "$@"; do
		cargo uninstall --root "$CARGO_INSTALL_ROOT" "$crate"
	done
}

source_is_installed() {
	local crate=${1:?crate required}
	[[ -f $CARGO_INSTALL_ROOT/.crates.toml ]] || return 1
	awk -v crate="\"$crate" \
		'$1 == crate { found = 1 } END { exit !found }' \
		"$CARGO_INSTALL_ROOT/.crates.toml"
}
