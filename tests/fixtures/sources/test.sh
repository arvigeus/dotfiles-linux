#!/usr/bin/env bash

source_prepare() {
	printf 'shared-enable\n' >>"$PACKAGE_TEST_LOG"
}

source_install() {
	printf 'shared-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

source_remove() {
	printf 'shared-remove' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

source_is_installed() {
	[[ $1 == present ]]
}
