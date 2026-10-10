#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SETUP_ROOT="$PROJECT_ROOT/tests/fixtures"
DISTRO=arch
PROJECT_ID=system
PACKAGE_TEST_LOG=$(mktemp)
export SETUP_ROOT DISTRO PROJECT_ID PACKAGE_TEST_LOG
trap 'rm -f -- "$PACKAGE_TEST_LOG"' EXIT

source "$PROJECT_ROOT/lib/package.sh"

pkg_native_install() {
	printf 'native-install' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
	return "${PACKAGE_TEST_NATIVE_STATUS:-0}"
}

pkg_native_remove() {
	printf 'native-remove' >>"$PACKAGE_TEST_LOG"
	printf ' %s' "$@" >>"$PACKAGE_TEST_LOG"
	printf '\n' >>"$PACKAGE_TEST_LOG"
	return "${PACKAGE_TEST_NATIVE_STATUS:-0}"
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
	arch:test/two arch:extra/nodejs arch:lib32-example
assert_log $'native-install nano linux\nshared-install one runtime/org.example.Platform/x86_64/stable\narch-install two\nextra-install nodejs\nmultilib-install lib32-example'

pkg_remove nano test/one arch:test/two
assert_log $'native-remove nano\nshared-remove one\narch-remove two'

# Dependency providers guard pkg_install with || return. That suppresses
# errexit inside the dispatcher, so failed transactions must propagate their
# status explicitly and stop before another source can mask the failure.
for DISTRO in arch fedora; do
	for operation in install remove; do
		if PACKAGE_TEST_NATIVE_STATUS=42 "pkg_$operation" nano test/one; then
			fail "$DISTRO native $operation failure was reported successful"
		else
			[[ $? == 42 ]] || fail "$DISTRO native $operation status was lost"
		fi
		assert_log "native-$operation nano"
	done
done
DISTRO=arch

# A source failure must also stop dispatch before a later source succeeds.
(
	# shellcheck disable=SC2329 # called indirectly by pkg_install/pkg_remove
	_pkg_plugin_call() {
		printf 'failed-source %s\n' "$2" >>"$PACKAGE_TEST_LOG"
		return 43
	}
	for operation in install remove; do
		if "pkg_$operation" test/one arch:test/two; then
			fail "$operation source failure was reported successful"
		else
			[[ $? == 43 ]] || fail "$operation source status was lost"
		fi
		assert_log "failed-source $operation"
	done
)

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

plan=$(mktemp)
printf '%s\t%s\t%s\n' \
	test/leaf "$SETUP_ROOT/module" source:arch:test \
	test/leaf "$SETUP_ROOT/module" nano \
	test/leaf "$SETUP_ROOT/module" nano \
	test/leaf "$SETUP_ROOT/module" arch:owned/one >"$plan"
pkg_install_plan "$plan"
rm -f -- "$plan"
assert_log $'arch-enable\nowned-prepare\nnative-install nano\nowned-install one'

plan=$(mktemp)
printf '%s\t%s\t%s\n' test/leaf "$SETUP_ROOT/module" 'source:../test' >"$plan"
if pkg_install_plan "$plan" 2>/dev/null; then
	fail 'path traversal in an explicit source selector was accepted'
fi
rm -f -- "$plan"

plan=$(mktemp)
printf '%s\t%s\t%s\n' test/leaf "$SETUP_ROOT/module" 'fedora:missing/package' >"$plan"
if pkg_install_plan "$plan" 2>/dev/null; then
	fail 'missing source for the other distro was not detected during validation'
fi
rm -f -- "$plan"

printf 'package contract: ok\n'
