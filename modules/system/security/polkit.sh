#!/usr/bin/env bash
## https://github.com/polkit-org/polkit
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	polkit
)

module_entrypoint "$@"
