#!/usr/bin/env bash

# Package specifications:
#   name                         native package for the current distro
#   distro:name                  native package, selected only on that distro
#   repository/name              repository package for every distro
#   distro:repository/name       repository package, selected only on that distro
#
# Repository plugins are resolved from the current distro first, then from the
# common repository directory. Unknown repositories are always an error.
_pkg_parse_spec() {
	local spec=${1:?package spec required}
	PKG_SCOPE=
	PKG_REPOSITORY=
	PKG_NAME=

	if [[ $spec == *:* ]]; then
		PKG_SCOPE=${spec%%:*}
		local remainder=${spec#*:}
		if [[ $remainder == */* ]]; then
			PKG_REPOSITORY=${remainder%%/*}
			PKG_NAME=${remainder#*/}
		else
			PKG_REPOSITORY=$PKG_SCOPE
			PKG_NAME=$remainder
		fi
	elif [[ $spec == */* ]]; then
		PKG_REPOSITORY=${spec%%/*}
		PKG_NAME=${spec#*/}
	else
		PKG_REPOSITORY=$DISTRO
		PKG_NAME=$spec
	fi

	[[ -n $PKG_REPOSITORY && -n $PKG_NAME && $spec != *$'\n'* ]] || {
		printf 'Invalid package spec: %s\n' "$spec" >&2
		return 1
	}
}

_pkg_spec_applies() {
	[[ -z $PKG_SCOPE || $PKG_SCOPE == "$DISTRO" ]]
}

_pkg_repository_plugin() {
	local repository=${1:?repository required}
	[[ $repository =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
		printf 'Invalid package repository: %s\n' "$repository" >&2
		return 1
	}

	local setup_root=${SETUP_ROOT:-${PROJECT_ROOT:-}}
	[[ -n $setup_root ]] || {
		printf 'SETUP_ROOT or PROJECT_ROOT is required for repository packages\n' >&2
		return 1
	}

	local plugin
	for plugin in \
		"$setup_root/distros/$DISTRO/repos/$repository.sh" \
		"$setup_root/distros/common/repos/$repository.sh"; do
		if [[ -f $plugin && ! -L $plugin ]]; then
			printf '%s\n' "$plugin"
			return
		fi
	done

	printf "Unknown package repository '%s' for %s\n" "$repository" "$DISTRO" >&2
	return 1
}

_pkg_repo_call() {
	local repository=${1:?repository required}
	local operation=${2:?repository operation required}
	shift 2

	local plugin
	plugin=$(_pkg_repository_plugin "$repository") || return
	(
		set -Eeuo pipefail
		# shellcheck disable=SC1090
		source "$plugin"
		local function="repo_$operation"
		declare -F "$function" >/dev/null || {
			printf "Repository '%s' does not support %s\n" "$repository" "$operation" >&2
			return 1
		}
		"$function" "$@"
	)
}

# Enable a repository dependency from another plugin without installing a
# synthetic package. Repository names use the same distro-first lookup.
pkg_repo_enable() {
	_pkg_repo_call "${1:?repository required}" enable
}

_pkg_apply() {
	local operation=${1:?package operation required}
	local native_operation=${2:?native package operation required}
	shift 2

	local spec repository index i
	local native_packages=()
	local repositories=()
	local repository_packages=()
	for spec in "$@"; do
		_pkg_parse_spec "$spec"
		_pkg_spec_applies || continue
		if [[ $PKG_REPOSITORY == "$DISTRO" ]]; then
			native_packages+=("$PKG_NAME")
			continue
		fi

		index=-1
		for ((i = 0; i < ${#repositories[@]}; i++)); do
			if [[ ${repositories[$i]} == "$PKG_REPOSITORY" ]]; then
				index=$i
				break
			fi
		done
		if ((index < 0)); then
			index=${#repositories[@]}
			repositories+=("$PKG_REPOSITORY")
			repository_packages+=("")
		fi
		repository_packages[$index]+="$PKG_NAME"$'\n'
	done

	((${#native_packages[@]} == 0)) || "$native_operation" "${native_packages[@]}"
	local packages=()
	for ((index = 0; index < ${#repositories[@]}; index++)); do
		mapfile -t packages <<<"${repository_packages[$index]%$'\n'}"
		repository=${repositories[$index]}
		_pkg_repo_call "$repository" "$operation" "${packages[@]}"
	done
}

pkg_install() {
	_pkg_apply install pkg_native_install "$@"
}

pkg_is_installed() {
	_pkg_parse_spec "${1:?package spec required}"
	_pkg_spec_applies || return 0
	if [[ $PKG_REPOSITORY == "$DISTRO" ]]; then
		pkg_native_is_installed "$PKG_NAME"
	else
		_pkg_repo_call "$PKG_REPOSITORY" is_installed "$PKG_NAME"
	fi
}
