#!/usr/bin/env bash
## rclone — cloud storage sync and mount utility
## https://rclone.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	rclone
)

module_entrypoint "$@"
