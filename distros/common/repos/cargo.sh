#!/usr/bin/env bash

readonly CARGO_INSTALL_ROOT=/usr/local

repo_install() {
	pkg_install cargo gcc
	local crate
	for crate in "$@"; do
		cargo install --locked --root "$CARGO_INSTALL_ROOT" "$crate"
	done
}

repo_is_installed() {
	local crate=${1:?crate required}
	[[ -f $CARGO_INSTALL_ROOT/.crates.toml ]] || return 1
	awk -v crate="\"$crate" \
		'$1 == crate { found = 1 } END { exit !found }' \
		"$CARGO_INSTALL_ROOT/.crates.toml"
}
