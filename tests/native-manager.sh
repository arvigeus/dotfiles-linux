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

[extra]
Include = /etc/pacman.d/mirrorlist
EOF

source "$PROJECT_ROOT/pm/arch/pacman.sh"
pkg_native_configure "$TEST_ROOT"
pkg_native_configure "$TEST_ROOT"
[[ $(grep -c '^ParallelDownloads = 10$' "$TEST_ROOT/etc/pacman.conf") == 1 ]]
[[ $(grep -c '^VerbosePkgLists$' "$TEST_ROOT/etc/pacman.conf") == 1 ]]

PACMAN_CONFIG="$TEST_ROOT/etc/pacman.conf"
pacman_repo_write core-x86-64-v3 core <<'EOF'
Usage = Sync Install Upgrade
Include = /etc/pacman.d/alhp-mirrorlist
EOF
pacman_repo_write extra-x86-64-v3 extra <<'EOF'
Usage = Sync Install Upgrade
Include = /etc/pacman.d/alhp-mirrorlist
EOF
pacman_repo_write multilib-x86-64-v3 multilib <<'EOF'
Usage = Sync Install Upgrade
Include = /etc/pacman.d/alhp-mirrorlist
EOF
pacman_repo_write multilib <<'EOF'
Include = /etc/pacman.d/mirrorlist
EOF
pacman_repo_write chaotic-aur <<'EOF'
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
pacman_repo_write ogc chaotic-aur <<'EOF'
Server = https://pacman.opengamingcollective.org
EOF
if pacman_repo_write ogc chaotic-aur <<'EOF'; then
Server = https://pacman.opengamingcollective.org
EOF
	printf 'unchanged Pacman repository was rewritten\n' >&2
	exit 1
fi
[[ $(grep -c '^\[ogc\]$' "$PACMAN_CONFIG") == 1 ]]
[[ $(grep -c '^\[chaotic-aur\]$' "$PACMAN_CONFIG") == 1 ]]
for repositories in \
	'core-x86-64-v3 core' \
	'extra-x86-64-v3 extra' \
	'multilib-x86-64-v3 multilib' \
	'ogc chaotic-aur'; do
	read -r first second <<<"$repositories"
	first_line=$(grep -n "^\[$first\]$" "$PACMAN_CONFIG")
	second_line=$(grep -n "^\[$second\]$" "$PACMAN_CONFIG")
	((${first_line%%:*} < ${second_line%%:*}))
done
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
