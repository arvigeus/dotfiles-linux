#!/usr/bin/env bash

# Global shell/environment helpers for independently executed ported modules.
shell_set_alias() {
	local group=${1:?group required} name=${2:?alias name required} command=${3:?command required}
	file_append "/etc/profile.d/ported-${group}.sh" <<EOF
alias ${name}='${command//\'/\'\\\'\'}'
EOF
}

shell_set_env() {
	local group=${1:?group required} name=${2:?name required} value=${3-}
	file_append "/etc/profile.d/ported-${group}.sh" <<EOF
export ${name}='${value//\'/\'\\\'\'}'
EOF
}

shell_profile() {
	local group=${1:?group required}
	file_append "/etc/profile.d/ported-${group}.sh"
}

system_set_env() {
	local group=${1:?group required} name=${2:?name required} value=${3-}
	file_append "/etc/environment.d/ported-${group}.conf" <<EOF
${name}=${value}
EOF
}
