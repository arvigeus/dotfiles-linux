#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(codex pi opencode claude lemonade)
module_entrypoint "$@"
