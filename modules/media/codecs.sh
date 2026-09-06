#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

# Fedora's complete multimedia group comes from RPM Fusion. On Arch this
# declaration is filtered from the plan.
packages=(fedora:rpmfusion/@multimedia)

module_entrypoint "$@"
