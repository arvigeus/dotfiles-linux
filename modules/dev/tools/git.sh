#!/usr/bin/env bash
## Git
## https://git-scm.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	git
)

pkg_install "${packages[@]}"

# https://git-scm.com/docs/git-config
file_write /etc/gitconfig << 'EOF'
[init]
	defaultBranch = master
EOF
