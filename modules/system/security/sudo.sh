#!/usr/bin/env bash
## Sudo conveniences
## Future: polkit rules, sudoers.d entries, permission management
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

# "please" — polite alias for sudo
shell_set_alias sudo please sudo
