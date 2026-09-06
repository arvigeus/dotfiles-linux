#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

module_check() {
	[[ $DISTRO == arch ]]
}

module_apply() {
	file_write /etc/makepkg.conf.d/makeflags.conf <<EOF
MAKEFLAGS="--jobs=$(nproc)"
EOF
}

module_entrypoint "$@"
