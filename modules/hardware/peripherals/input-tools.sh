#!/usr/bin/env bash
## Input-device diagnostics
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	evtest
)

module_entrypoint "$@"
