#!/usr/bin/env bash
## GravityMark — cross-platform GPU benchmark
## https://gravitymark.tellusim.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

# shellcheck disable=SC2034 # consumed by module_entrypoint through a nameref
packages=(
	arch:pkgbuild/gravitymark
	fedora:rpmspec/gravitymark
)

module_entrypoint "$@"
