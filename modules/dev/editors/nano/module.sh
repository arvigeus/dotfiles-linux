#!/usr/bin/env bash
## Nano - Text Editor
## https://www.nano-editor.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

module_healthcheck() {
	repo_health https://github.com/galenguyer/nano-syntax-highlighting -m 12
}

# shellcheck disable=SC2034 # consumed by module_entrypoint through a nameref
packages=(
	nano
	arch:nano-syntax-highlighting
	fedora:rpmspec/nano-syntax-highlighting
)

module_entrypoint "$@"
