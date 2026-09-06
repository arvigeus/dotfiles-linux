#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(api-client bat delta devtoolbox distrobox fastfetch git just lsd make meld mise podman shell)
module_entrypoint "$@"
