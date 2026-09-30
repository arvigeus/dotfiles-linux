#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(package-sources archive bash shell utils xdg)
module_entrypoint "$@"
