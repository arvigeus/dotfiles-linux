#!/usr/bin/env bash
## DOS game and application emulation
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

pkg_install dosbox
