#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(tools geekbench gravity-mark)
module_entrypoint "$@"
