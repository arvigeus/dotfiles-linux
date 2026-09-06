#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	udisks2
)

module_apply() {
	systemctl enable fstrim.timer
}

module_entrypoint "$@"
