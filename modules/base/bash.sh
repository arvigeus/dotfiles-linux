#!/usr/bin/env bash
## Bash — Bourne Again SHell
## https://www.gnu.org/software/bash/
##
## Learning resources:
## - https://devhints.io/bash
## - https://github.com/dylanaraps/pure-bash-bible
## - https://tldp.org/LDP/abs/html/abs-guide.html
## - https://www.gnu.org/software/bash/manual/html_node/index.html
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

# Manually reload bashrc: source ~/.bashrc

# Drop duplicate consecutive lines from history.
module_apply() {
	shell_set_env bash HISTCONTROL ignoredups
	# Keep history out of $HOME root, in the XDG state location.
	install -d -m 0755 "$HOME/.local/state/bash"
	# shellcheck disable=SC2016
	shell_set_env bash HISTFILE '$HOME/.local/state/bash/history'
}

module_entrypoint "$@"
