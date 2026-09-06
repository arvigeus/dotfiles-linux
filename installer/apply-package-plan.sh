#!/usr/bin/env bash
set -Eeuo pipefail

plan=${1:?package plan required}
: "${SETUP_ROOT:?SETUP_ROOT is required}"
: "${DISTRO:?DISTRO is required}"
: "${PACKAGE_MANAGER:?PACKAGE_MANAGER is required}"

# Source plugins may use the same atomic file helpers as modules.
# shellcheck source=lib/module.sh
source "$SETUP_ROOT/lib/module.sh"

pkg_install_plan "$plan"
