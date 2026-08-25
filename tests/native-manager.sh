#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/etc/dnf"

cat >"$TEST_ROOT/etc/pacman.conf" <<'EOF'
[options]
#VerbosePkgLists
#ParallelDownloads = 5

[core]
Include = /etc/pacman.d/mirrorlist
EOF

source "$PROJECT_ROOT/pm/arch/pacman.sh"
pkg_native_configure "$TEST_ROOT"
pkg_native_configure "$TEST_ROOT"
[[ $(grep -c '^ParallelDownloads = 10$' "$TEST_ROOT/etc/pacman.conf") == 1 ]]
[[ $(grep -c '^VerbosePkgLists$' "$TEST_ROOT/etc/pacman.conf") == 1 ]]

PACMAN_CONFIG="$TEST_ROOT/etc/pacman.conf"
pacman_repo_write chaotic-aur <<'EOF'
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
pacman_repo_write ogc chaotic-aur <<'EOF'
Server = https://pacman.opengamingcollective.org
EOF
if pacman_repo_write ogc chaotic-aur <<'EOF'
Server = https://pacman.opengamingcollective.org
EOF
then
	printf 'unchanged Pacman repository was rewritten\n' >&2
	exit 1
fi
[[ $(grep -c '^\[ogc\]$' "$PACMAN_CONFIG") == 1 ]]
[[ $(grep -c '^\[chaotic-aur\]$' "$PACMAN_CONFIG") == 1 ]]
ogc_line=$(grep -n '^\[ogc\]$' "$PACMAN_CONFIG")
chaotic_line=$(grep -n '^\[chaotic-aur\]$' "$PACMAN_CONFIG")
(( ${ogc_line%%:*} < ${chaotic_line%%:*} ))
unset PACMAN_CONFIG

cat >"$TEST_ROOT/etc/dnf/dnf.conf" <<'EOF'
[main]
gpgcheck=True
EOF

source "$PROJECT_ROOT/pm/fedora/dnf.sh"
pkg_native_configure "$TEST_ROOT"
pkg_native_configure "$TEST_ROOT"
for option in \
	'minrate=100k' \
	'timeout=15' \
	'retries=10' \
	'fastestmirror=True' \
	'max_parallel_downloads=10'; do
	[[ $(grep -c "^$option$" "$TEST_ROOT/etc/dnf/dnf.conf") == 1 ]]
done

printf 'native manager configuration: ok\n'
