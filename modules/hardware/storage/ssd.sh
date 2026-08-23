#!/usr/bin/env bash
## SSD maintenance policy
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

systemctl enable fstrim.timer
