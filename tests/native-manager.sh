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

source "$PROJECT_ROOT/sources/arch/pacman.sh"
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
if pacman_repo_write ogc chaotic-aur <<'EOF'
Server = https://pacman.opengamingcollective.org
EOF
then
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

# A booted Arch root must contain its own rebuild tool; live-ISO availability
# alone is insufficient. Capture the backend's real base-install invocation.
(
	source "$PROJECT_ROOT/installer/distros/arch/backend.sh"
	KERNEL_PACKAGE=linux MICROCODE_PACKAGE=amd-ucode TARGET_ROOT="$TEST_ROOT/root"
	log() { :; }
	unshare() { printf '%s\n' "$@" >"$TEST_ROOT/base-install-arguments"; }
	distro_install_base_system
)
rg -qx 'arch-install-scripts' "$TEST_ROOT/base-install-arguments"
rg -qx -- '--pid' "$TEST_ROOT/base-install-arguments"
rg -qx 'pacstrap' "$TEST_ROOT/base-install-arguments"

EXTRA_PACKAGES=()
pkg_native_install() {
	EXTRA_PACKAGES=("$@")
}
source "$PROJECT_ROOT/sources/arch/extra.sh"
source_install nodejs npm
[[ ${EXTRA_PACKAGES[*]} == 'extra/nodejs extra/npm' ]]

cat >"$TEST_ROOT/etc/dnf/dnf.conf" <<'EOF'
[main]
gpgcheck=True
EOF

source "$PROJECT_ROOT/sources/fedora/dnf.sh"
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
