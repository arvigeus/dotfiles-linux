#!/usr/bin/env bash
## Syncplay — shared viewing.
## https://syncplay.pl/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

packages=(
	syncplay
	arch:pyside6 # needed for interface (marked as optional for Arch)
)

module_healthcheck() {
	repo_health https://github.com/syncplay/syncplay -m 12
}

module_entrypoint "$@"
