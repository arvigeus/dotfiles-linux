#!/usr/bin/env bash

pm_enable() {
	printf 'shared-enable\n' >>"$PACKAGE_TEST_LOG"
}

pm_install() {
	printf 'shared-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pm_remove() {
	printf 'shared-remove' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pm_is_installed() {
	[[ $1 == present ]]
}
