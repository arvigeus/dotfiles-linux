#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(package performance security virtualization mirrorlist)
module_entrypoint "$@"
