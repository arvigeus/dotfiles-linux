#!/usr/bin/env bash

# Package specifications:
#   name                         native package for the current distro
#   distro:name                  native package, only on that distro
#   source/name                  package handled by pm/source.sh
#   distro:source/name           package handled by pm/distro/source.sh
#
# A distro scope is selection, not a repository name. There is deliberately no
# fallback between distro-specific and shared plugins: the spelling identifies
# one exact plugin.
_pkg_parse_spec() {
	local spec=${1:?package spec required}
	local remainder=$spec
	PKG_SCOPE=
	PKG_SOURCE=native
	PKG_NAME=

	[[ $spec != *[[:space:]]* ]] || {
		printf 'Invalid package spec: %q\n' "$spec" >&2
		return 1
	}

	if [[ $spec == *:* ]]; then
		PKG_SCOPE=${spec%%:*}
		remainder=${spec#*:}
		case $PKG_SCOPE in
		arch | fedora) ;;
		*)
			printf 'Unknown distro scope in package spec: %s\n' "$spec" >&2
			return 1
			;;
		esac
		[[ $remainder != *:* ]] || {
			printf 'Invalid package spec: %s\n' "$spec" >&2
			return 1
		}
	fi

	if [[ $remainder == */* ]]; then
		PKG_SOURCE=${remainder%%/*}
		PKG_NAME=${remainder#*/}
		[[ $PKG_SOURCE =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
			printf 'Invalid package source in spec: %s\n' "$spec" >&2
			return 1
		}
	else
		PKG_NAME=$remainder
	fi

	[[ -n $PKG_NAME && $PKG_NAME != /* ]] || {
		printf 'Invalid package name in spec: %s\n' "$spec" >&2
		return 1
	}

	# Arch's lib32 namespace is backed by the optional multilib repository.
	# Keep declarations concise while still enabling that repository on demand.
	if [[ $PKG_SCOPE == arch && $PKG_SOURCE == native && $PKG_NAME == lib32-* ]]; then
		PKG_SOURCE=multilib
	fi
}

_pkg_spec_applies() {
	[[ -z $PKG_SCOPE || $PKG_SCOPE == "$DISTRO" ]]
}

_pkg_plugin_path() {
	local scope=$1 source=${2:?package source required}
	local setup_root=${SETUP_ROOT:-${PROJECT_ROOT:-}}
	[[ -n $setup_root ]] || {
		printf 'SETUP_ROOT or PROJECT_ROOT is required for package plugins\n' >&2
		return 1
	}

	local plugin
	if [[ -n $scope ]]; then
		plugin="$setup_root/pm/$scope/$source.sh"
	else
		plugin="$setup_root/pm/$source.sh"
	fi

	if [[ -f $plugin && ! -L $plugin ]]; then
		printf '%s\n' "$plugin"
		return
	fi

	if [[ -n $scope ]]; then
		printf "Unknown package source '%s' for %s\n" "$source" "$scope" >&2
	else
		printf "Unknown shared package source '%s'\n" "$source" >&2
	fi
	return 1
}

_pkg_plugin_call() {
	local plugin=${1:?plugin path required}
	local operation=${2:?plugin operation required}
	shift 2

	(
		set -Eeuo pipefail
		# shellcheck disable=SC1090
		source "$plugin"
		local function="pm_$operation"
		declare -F "$function" >/dev/null || {
			printf "Package plugin '%s' does not support %s\n" "$plugin" "$operation" >&2
			return 1
		}
		"$function" "$@"
	)
}

# Enable another source from a plugin without inventing a synthetic package.
# Usage: pkg_repo_enable flathub | pkg_repo_enable arch:chaotic-aur
pkg_repo_enable() {
	local selector=${1:?package source required}
	local scope='' source=$selector
	[[ $selector != */* && $selector != *[[:space:]]* ]] || {
		printf 'Invalid package source selector: %s\n' "$selector" >&2
		return 1
	}
	if [[ $selector == *:* ]]; then
		scope=${selector%%:*}
		source=${selector#*:}
		case $scope in
		arch | fedora) ;;
		*)
			printf 'Unknown distro scope in package source: %s\n' "$selector" >&2
			return 1
			;;
		esac
		[[ $scope == "$DISTRO" ]] || return 0
	fi
	[[ $source =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
		printf 'Invalid package source selector: %s\n' "$selector" >&2
		return 1
	}

	local plugin
	plugin=$(_pkg_plugin_path "$scope" "$source") || return
	_pkg_plugin_call "$plugin" enable
}

_pkg_apply() {
	local operation=${1:?package operation required}
	local native_operation=${2:?native package operation required}
	shift 2

	local spec plugin index i
	local native_packages=()
	local plugins=()
	local plugin_packages=()
	for spec in "$@"; do
		_pkg_parse_spec "$spec" || return
		_pkg_spec_applies || continue
		if [[ $PKG_SOURCE == native ]]; then
			native_packages+=("$PKG_NAME")
			continue
		fi

		plugin=$(_pkg_plugin_path "$PKG_SCOPE" "$PKG_SOURCE") || return
		index=-1
		for ((i = 0; i < ${#plugins[@]}; i++)); do
			if [[ ${plugins[$i]} == "$plugin" ]]; then
				index=$i
				break
			fi
		done
		if ((index < 0)); then
			index=${#plugins[@]}
			plugins+=("$plugin")
			plugin_packages+=("")
		fi
		plugin_packages[$index]+="$PKG_NAME"$'\n'
	done

	((${#native_packages[@]} == 0)) || "$native_operation" "${native_packages[@]}"
	local packages=()
	for ((index = 0; index < ${#plugins[@]}; index++)); do
		mapfile -t packages <<<"${plugin_packages[$index]%$'\n'}"
		_pkg_plugin_call "${plugins[$index]}" "$operation" "${packages[@]}"
	done
}

pkg_install() {
	_pkg_apply install pkg_native_install "$@"
}

pkg_remove() {
	_pkg_apply remove pkg_native_remove "$@"
}

pkg_is_installed() {
	_pkg_parse_spec "${1:?package spec required}" || return
	_pkg_spec_applies || return 0
	if [[ $PKG_SOURCE == native ]]; then
		pkg_native_is_installed "$PKG_NAME"
	else
		local plugin
		plugin=$(_pkg_plugin_path "$PKG_SCOPE" "$PKG_SOURCE") || return
		_pkg_plugin_call "$plugin" is_installed "$PKG_NAME"
	fi
}
