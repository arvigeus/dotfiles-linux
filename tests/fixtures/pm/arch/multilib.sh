#!/usr/bin/env bash

pm_enable() {
	printf 'multilib-enable\n' >>"$PACKAGE_TEST_LOG"
}

pm_install() {
	printf 'multilib-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pm_remove() {
	printf 'multilib-remove' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pm_is_installed() {
	[[ $1 == present ]]
}
