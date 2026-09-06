#!/usr/bin/env bash
## Interactive shell defaults shared across shell environments
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

module_apply() {
	# Friendlier defaults for GNU coreutils commands.
	shell_set_alias coreutils mkdir 'mkdir -p -v'
	shell_set_alias coreutils df 'df -h'
	shell_set_alias coreutils du 'du -c -h'
	shell_set_alias coreutils rm 'rm -i'
	shell_set_alias coreutils cp 'cp -i'
	shell_set_alias coreutils mv 'mv -i'
	# shell_set_alias coreutils ls 'ls --all --human-readable --color=always --group-directories-first --format=long --classify'

	# dmesg with human-readable timestamps and color.
	shell_set_alias util-linux dmesg 'dmesg -HL'

	# $HOME/.local/bin on PATH — XDG-standard location for per-user binaries.
	# shellcheck disable=SC2016
	system_set_env path PATH '$HOME/.local/bin:$PATH'

	# List completions on first Tab when ambiguous, instead of beeping and requiring a second Tab.
	file_append /etc/inputrc <<'EOF'
set show-all-if-ambiguous on
EOF
}

module_entrypoint "$@"
