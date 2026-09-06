#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(fresh micro nano vscode zed)
module_entrypoint "$@"
