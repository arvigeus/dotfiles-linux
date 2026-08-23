#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

pkg_install nano
install -Dm644 "$MODULE_DIR/nanorc" /etc/nanorc
