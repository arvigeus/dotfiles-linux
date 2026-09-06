#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"

module_check() {
	[[ $DISTRO == arch ]] || return 1
	if ! LC_ALL=C /lib/ld-linux-x86-64.so.2 --help 2>&1 |
		grep -Fq 'x86-64-v3 (supported, searched)'; then
		printf 'Skipping ALHP x86-64-v3: this CPU does not advertise v3 support\n' >&2
		return 1
	fi
}

# shellcheck disable=SC2034 # consumed by module_entrypoint through a nameref
sources=(arch:alhp)

module_entrypoint "$@"
