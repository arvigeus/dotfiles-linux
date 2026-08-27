#!/usr/bin/env bash

# Explicit Fedora scope for packages that use the shared npm backend only on
# Fedora. Package specs do not fall back from scoped to shared plugins.
# shellcheck source=pm/npm.sh disable=SC1091
source "$SETUP_ROOT/pm/npm.sh"
