#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(audio bluetooth cpu devices firmware gpu keyboard memory network peripherals storage wireless)
module_entrypoint "$@"
