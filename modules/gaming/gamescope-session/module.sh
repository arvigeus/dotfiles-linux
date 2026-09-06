#!/usr/bin/env bash
## Dedicated Gamescope/Steam login session
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

module_entrypoint "$@"
