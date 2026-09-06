#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(codecs graphics music tools video)
module_entrypoint "$@"
