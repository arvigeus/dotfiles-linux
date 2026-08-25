#!/usr/bin/env bash
## Fedora managed kernel
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
[[ $DISTRO == fedora ]] || exit 0

pkg_install fedora:ogc/kernel
file_write /etc/system/kernel-flavor <<'EOF'
ogc
EOF
