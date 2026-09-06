#!/usr/bin/env bash
## Desktop document and PDF viewer
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(okular)

module_entrypoint "$@"
