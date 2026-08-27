#!/usr/bin/env bash
## Desktop image viewer
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

pkg_install gwenview
