#!/usr/bin/env bash
## Preserve system-wide Bluetooth pairings across clean-root rebuilds.
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

preserve_path /var/lib/bluetooth
