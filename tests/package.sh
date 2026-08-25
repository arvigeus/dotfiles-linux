#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SETUP_ROOT="$PROJECT_ROOT/tests/fixtures"
DISTRO=arch
PACKAGE_TEST_LOG=$(mktemp)
export SETUP_ROOT DISTRO PACKAGE_TEST_LOG
trap 'rm -f -- "$PACKAGE_TEST_LOG"' EXIT

source "$PROJECT_ROOT/lib/package.sh"

pkg_native_install() {
	printf 'native-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pkg_native_remove() {
	printf 'native-remove' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
}

pkg_native_is_installed() {
	[[ $1 == present ]]
}

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_log() {
	local expected=$1 actual
	actual=$(<"$PACKAGE_TEST_LOG")
	[[ $actual == "$expected" ]] || fail "unexpected dispatch log
expected:
$expected
actual:
$actual"
	: >"$PACKAGE_TEST_LOG"
}

pkg_install nano arch:linux fedora:ignored \
	test/one test/runtime/org.example.Platform/x86_64/stable \
	arch:test/two arch:lib32-example
assert_log $'native-install nano linux\nshared-install one runtime/org.example.Platform/x86_64/stable\narch-install two\nmultilib-install lib32-example'

pkg_remove nano test/one arch:test/two
assert_log $'native-remove nano\nshared-remove one\narch-remove two'

pkg_repo_enable test
pkg_repo_enable arch:test
pkg_repo_enable fedora:test
assert_log $'shared-enable\narch-enable'

pkg_is_installed present || fail 'native installed lookup failed'
pkg_is_installed test/present || fail 'shared installed lookup failed'
pkg_is_installed arch:test/present || fail 'scoped installed lookup failed'
pkg_is_installed fedora:absent || fail 'other-distro spec must be a no-op'
pkg_is_installed absent && fail 'missing native package reported installed'
pkg_is_installed test/absent && fail 'missing plugin package reported installed'

pkg_install aur/example 2>/dev/null && fail 'unscoped AUR unexpectedly resolved'
pkg_install arch/example 2>/dev/null && fail 'distro/source syntax became native syntax'
pkg_install fedorra:example 2>/dev/null && fail 'unknown distro scope was ignored'
pkg_install test/ 2>/dev/null && fail 'empty package name was accepted'

printf 'package contract: ok\n'
