#!/usr/bin/env bash
## OpenCode terminal coding agent
## https://opencode.ai/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:extra/opencode
	fedora:terra/opencode
)
module_entrypoint "$@"
