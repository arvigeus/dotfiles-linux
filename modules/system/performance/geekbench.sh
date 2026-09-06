#!/usr/bin/env bash
## Geekbench 6
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
    arch:aur/geekbench
)

module_entrypoint "$@"
