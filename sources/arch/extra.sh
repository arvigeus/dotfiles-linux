#!/usr/bin/env bash

# Select a package explicitly from Arch's official Extra repository. This is a
# narrow escape hatch for ABI-sensitive tools when an earlier overlay contains
# a stale rebuild that would otherwise shadow the coherent official package.
source_prepare() {
	:
}

source_install() {
	local package packages=()
	for package in "$@"; do
		packages+=("extra/$package")
	done
	pkg_native_install "${packages[@]}"
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
