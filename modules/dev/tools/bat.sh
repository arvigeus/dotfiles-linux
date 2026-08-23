#!/usr/bin/env bash
## bat — cat clone with syntax highlighting and Git integration
## https://github.com/sharkdp/bat
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

repo_health https://github.com/sharkdp/bat -m 12

packages=(
	bat
)

pkg_install "${packages[@]}"

shell_set_alias bat cat 'bat --paging=never'
