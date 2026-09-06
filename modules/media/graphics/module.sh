#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

members=(gimp image-viewer photopea)

module_entrypoint "$@"
