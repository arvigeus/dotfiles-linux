#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(polkit sudo ufw ssh)
module_entrypoint "$@"
