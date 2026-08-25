#!/usr/bin/env bash

pm_enable() {
	printf 'arch-enable\n' >>"$PACKAGE_TEST_LOG"
}

pm_install() {
	printf 'arch-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pm_remove() {
	printf 'arch-remove' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pm_is_installed() {
	[[ $1 == present ]]
}
