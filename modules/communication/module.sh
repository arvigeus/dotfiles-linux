#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(kdeconnect discord telegram whatsapp)
module_entrypoint "$@"
