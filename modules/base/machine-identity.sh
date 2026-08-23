#!/usr/bin/env bash
## Preserve identities that must remain stable across clean-root rebuilds.
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

preserve_path \
	/etc/machine-id \
	'/etc/ssh/ssh_host_*'
