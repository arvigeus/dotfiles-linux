#!/usr/bin/env bash
## Keyboard languages; individual leaves can also be selected separately.
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(bg vn)
module_entrypoint "$@"
