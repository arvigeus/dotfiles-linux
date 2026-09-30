#!/usr/bin/env bash
## Small baseline command-line utilities
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

packages=(
	bc
	less
	rsync
	wget
)

module_apply() {
	# Keep less history out of $HOME root, in the XDG state location.
	install -d -m 0755 "$HOME/.local/state/less"
	# shellcheck disable=SC2016
	shell_set_env less LESSHISTFILE '$HOME/.local/state/less/history'
}

module_entrypoint "$@"
