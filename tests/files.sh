#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SETUP_ROOT=$PROJECT_ROOT
DISTRO=arch
PACKAGE_MANAGER=pacman
PROJECT_ID=system
PRESERVE_REQUESTS_FILE=/dev/null
export SETUP_ROOT DISTRO PACKAGE_MANAGER PROJECT_ID PRESERVE_REQUESTS_FILE
source "$PROJECT_ROOT/lib/module.sh"

TEST_DIRECTORY=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIRECTORY"' EXIT
destination="$TEST_DIRECTORY/example.conf"
owner=$(id -u)
group=$(id -g)

printf 'one\n' | file_write -m 0600 -o "$owner" -g "$group" "$destination"
[[ $(<"$destination") == one ]] || { printf 'file_write content failed\n' >&2; exit 1; }
[[ $(stat -c %a "$destination") == 600 ]] || { printf 'file_write mode failed\n' >&2; exit 1; }
[[ $(stat -c %u:%g "$destination") == "$owner:$group" ]] || {
	printf 'file_write ownership failed\n' >&2
	exit 1
}

printf 'two\n' | file_write "$destination"
[[ $(<"$destination") == two ]] || { printf 'file replacement failed\n' >&2; exit 1; }
[[ $(stat -c %a "$destination") == 600 ]] || { printf 'existing mode was not retained\n' >&2; exit 1; }

printf 'three\n' | file_append "$destination"
[[ $(<"$destination") == $'two\nthree' ]] || { printf 'file_append failed\n' >&2; exit 1; }

printf 'file helpers: ok\n'
