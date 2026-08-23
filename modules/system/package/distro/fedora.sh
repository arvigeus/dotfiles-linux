#!/usr/bin/env bash
## Fedora package-manager configuration
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
[[ $DISTRO == fedora ]] || exit 0

file_append /etc/dnf/dnf.conf <<'EOF'
max_parallel_downloads=10
EOF
