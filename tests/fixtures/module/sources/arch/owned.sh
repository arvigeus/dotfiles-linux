#!/usr/bin/env bash

source_prepare() {
	printf 'owned-prepare\n' >>"$PACKAGE_TEST_LOG"
}

source_install() {
	printf 'owned-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

source_is_installed() {
	return 1
}

source_remove() {
	:
}
