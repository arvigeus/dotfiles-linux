#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
[[ $DISTRO == arch ]] || exit 0

file_write /etc/makepkg.conf.d/makeflags.conf << EOF
MAKEFLAGS="--jobs=$(nproc)"
EOF
