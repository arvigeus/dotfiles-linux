#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(chromium firefox tor-browser zen)
module_entrypoint "$@"
