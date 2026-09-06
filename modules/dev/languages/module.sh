#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(deno nodejs rust)
module_entrypoint "$@"
