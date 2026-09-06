#!/usr/bin/env bash

_ALHP_LEVEL=x86-64-v3

source_prepare() {
	local refresh=false
	LC_ALL=C /lib/ld-linux-x86-64.so.2 --help 2>&1 |
		grep -Fq 'x86-64-v3 (supported, searched)' || {
		printf 'Refusing ALHP x86-64-v3 on an unsupported CPU\n' >&2
		return 1
	}

	# ALHP publishes these trust and mirror packages through the AUR; use their
	# signed Chaotic-AUR builds so repository setup does not bootstrap an AUR
	# toolchain before the optimized overlay is active.
	pkg_install \
		arch:chaotic-aur/alhp-keyring \
		arch:chaotic-aur/alhp-mirrorlist

	if pacman_repo_write "core-$_ALHP_LEVEL" core <<'EOF'; then
Usage = Sync Install Upgrade
Include = /etc/pacman.d/alhp-mirrorlist
EOF
		refresh=true
	fi
	if pacman_repo_write "extra-$_ALHP_LEVEL" extra <<'EOF'; then
Usage = Sync Install Upgrade
Include = /etc/pacman.d/alhp-mirrorlist
EOF
		refresh=true
	fi
	# This may be written before [multilib] is enabled. pacman_repo_write appends
	# it in that case, and the multilib plugin later appends the official fallback.
	if pacman_repo_write "multilib-$_ALHP_LEVEL" multilib <<'EOF'; then
Usage = Sync Install Upgrade
Include = /etc/pacman.d/alhp-mirrorlist
EOF
		refresh=true
	fi

	# Enabling an optimized overlay without completing the matching upgrade can
	# leave a partial package set. Perform ALHP's documented full-system upgrade
	# only when this clean candidate gained or changed repository declarations.
	[[ $refresh == false ]] || pacman -Syu --needed --noconfirm
}
