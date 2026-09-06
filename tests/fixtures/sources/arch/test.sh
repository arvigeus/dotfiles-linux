#!/usr/bin/env bash

source_prepare() {
	printf 'arch-enable\n' >>"$PACKAGE_TEST_LOG"
}

source_install() {
	printf 'arch-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

source_remove() {
	printf 'arch-remove' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

source_is_installed() {
	[[ $1 == present ]]
}
