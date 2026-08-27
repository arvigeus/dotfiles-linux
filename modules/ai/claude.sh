#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2317
## Claude Code terminal coding assistant
## Intentionally disabled until this module is explicitly re-enabled.
exit 0

set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:aur/claude
	fedora:claude/claude
)
pkg_install "${packages[@]}"
