#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(docs document-viewer ebook-reader productivity btrust)
module_entrypoint "$@"
