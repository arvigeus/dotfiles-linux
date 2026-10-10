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

# Exercise real source preparation with third-party repositories already
# present and no active official multilib fallback. Stub package transactions
# so every operation checks the repository order without modifying the host.
(
	SETUP_ROOT=$PROJECT_ROOT DISTRO=arch
	source "$PROJECT_ROOT/lib/package.sh"
	PACMAN_CONFIG="$TEST_ROOT/sources-pacman.conf"
	cat >"$PACMAN_CONFIG" <<'EOF'
[options]
[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
#[multilib]
#Include = /etc/pacman.d/mirrorlist
[ogc]
Server = https://pacman.opengamingcollective.org
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
	assert_multilib_priority() {
		local official third_party
		official=$(rg -n '^\[multilib\]$' "$PACMAN_CONFIG")
		for repo in ogc chaotic-aur; do
			third_party=$(rg -n "^\[$repo\]$" "$PACMAN_CONFIG")
			((${official%%:*} < ${third_party%%:*}))
		done
	}
	pacman() {
		assert_multilib_priority
		printf '%s\n' "$*" >>"$TEST_ROOT/source-transactions"
	}
	pkg_native_is_installed() { return 0; }
	pkg_native_install() {
		assert_multilib_priority
		printf 'install %s\n' "$*" >>"$TEST_ROOT/source-transactions"
	}
	pkg_repo_enable arch:multilib
	pkg_repo_enable arch:multilib
	[[ $(cat "$TEST_ROOT/source-transactions") == '-Syu --needed --noconfirm' ]]
	[[ $(rg -c '^\[multilib\]$' "$PACMAN_CONFIG") == 1 ]]

	# Supply the CPU capability result only; ALHP's real prerequisite dispatch,
	# repository writer and upgrade sequencing remain under test.
	grep() {
		if [[ $* == '-Fq x86-64-v3 (supported, searched)' ]]; then
			command cat >/dev/null
			return 0
		fi
		command grep "$@"
	}
	# Start ALHP from the missing-fallback configuration again.
	sed -i '/^\[multilib\]$/,+1d' "$PACMAN_CONFIG"
	: >"$TEST_ROOT/source-transactions"
	pkg_repo_enable arch:alhp
	[[ $(cat "$TEST_ROOT/source-transactions") == $'-Syu --needed --noconfirm\n-Sy --noconfirm\ninstall chaotic-aur/alhp-keyring chaotic-aur/alhp-mirrorlist\n-Syu --needed --noconfirm' ]]
	overlay=$(rg -n '^\[multilib-x86-64-v3\]$' "$PACMAN_CONFIG")
	official=$(rg -n '^\[multilib\]$' "$PACMAN_CONFIG")
	((${overlay%%:*} < ${official%%:*}))
	cp "$PACMAN_CONFIG" "$TEST_ROOT/sources-pacman-before.conf"
	: >"$TEST_ROOT/source-transactions"
	pkg_repo_enable arch:multilib
	pkg_repo_enable arch:alhp
	cmp "$PACMAN_CONFIG" "$TEST_ROOT/sources-pacman-before.conf"
	[[ $(cat "$TEST_ROOT/source-transactions") == 'install chaotic-aur/alhp-keyring chaotic-aur/alhp-mirrorlist' ]]
)

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
