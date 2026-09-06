#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(diablo-1 nethack red-alert-2 roblox)
module_entrypoint "$@"
