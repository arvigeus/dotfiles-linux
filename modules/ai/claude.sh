#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2317
## Claude Code terminal coding assistant
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:aur/claude-code
	fedora:claude/claude-code
)

# Kept out of the host aggregate until its source is intentionally reviewed.
module_entrypoint "$@"
