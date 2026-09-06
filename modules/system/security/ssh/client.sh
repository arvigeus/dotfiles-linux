#!/usr/bin/env bash
## OpenSSH client for outbound connections
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:openssh
	fedora:openssh-clients
)

module_entrypoint "$@"
