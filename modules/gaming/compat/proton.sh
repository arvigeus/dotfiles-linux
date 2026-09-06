#!/usr/bin/env bash
## Proton helper tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	flathub/com.github.Matoking.protontricks
	flathub/com.vysp3r.ProtonPlus
)

module_entrypoint "$@"
