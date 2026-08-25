#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

# Fedora's complete multimedia group comes from RPM Fusion. On Arch there is no
# extra source to enable, so this declaration is a no-op.
pkg_install fedora:rpmfusion/@multimedia
