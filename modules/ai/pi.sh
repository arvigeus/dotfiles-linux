#!/usr/bin/env bash
## Pi coding agent
## https://pi.dev/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:extra/nodejs
	arch:extra/npm
	arch:aur/pi-coding-agent
	fedora:npm/@earendil-works/pi-coding-agent
)
module_entrypoint "$@"
