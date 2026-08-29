#!/usr/bin/env bash
## Early package setup
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

init_arch_packages() {
	# ALHP: https://somegit.dev/ALHP/ALHP.GO
	# Installing v3 binaries on an unsupported CPU can make the system unbootable.
	# The GA402RK's Ryzen 9 6900HS passes this glibc feature-level check; keeping the
	# runtime gate also makes rebuilds and VMs fall back safely to official Arch.
	if ! LC_ALL=C /lib/ld-linux-x86-64.so.2 --help 2>&1 |
		grep -Fq 'x86-64-v3 (supported, searched)'; then
		printf 'Skipping ALHP x86-64-v3: this CPU does not advertise v3 support\n' >&2
		return
	fi

	pkg_repo_enable arch:alhp
}

case $DISTRO in
arch) init_arch_packages ;;
fedora) : ;;
esac
