#!/usr/bin/env bash

# Package specifications:
#   name                         native package for the current distro
#   distro:name                  native package, only on that distro
#   source/name                  package handled by sources/source.sh
#   distro:source/name           package handled by sources/distro/source.sh
#
# A distro scope controls applicability. Source lookup prefers a scoped plugin
# but may use a shared plugin, allowing declarations such as
# fedora:cargo/just-lsp without pretending Cargo is a Fedora repository.
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

_pkg_parse_source_selector() {
	local selector=${1:?package source selector required}
	PKG_SCOPE=
	PKG_SOURCE=$selector
	[[ $selector != */* && $selector != *[[:space:]]* ]] || {
		printf 'Invalid explicit source selector: %s\n' "$selector" >&2
		return 1
	}
	if [[ $selector == *:* ]]; then
		PKG_SCOPE=${selector%%:*}
		PKG_SOURCE=${selector#*:}
		case $PKG_SCOPE in
		arch | fedora) ;;
		*)
			printf 'Unknown distro scope in source selector: %s\n' "$selector" >&2
			return 1
			;;
		esac
	fi
	[[ $PKG_SOURCE =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
		printf 'Invalid explicit source selector: %s\n' "$selector" >&2
		return 1
	}
}

_pkg_plugin_path() {
	local scope=$1 source=${2:?package source required} module_dir=${3:-}
	local setup_root=${SETUP_ROOT:-${PROJECT_ROOT:-}}
	[[ -n $setup_root ]] || {
		printf 'SETUP_ROOT or PROJECT_ROOT is required for package plugins\n' >&2
		return 1
	}

	local plugin candidates=()
	if [[ -n $module_dir ]]; then
		if [[ -n $scope ]]; then
			candidates+=("$module_dir/sources/$scope/$source.sh")
		fi
		candidates+=("$module_dir/sources/$source.sh")
	fi

	if [[ -n $scope ]]; then
		candidates+=("$setup_root/sources/$scope/$source.sh")
	fi
	candidates+=("$setup_root/sources/$source.sh")

	for plugin in "${candidates[@]}"; do
		if [[ -f $plugin && ! -L $plugin ]]; then
			printf '%s\n' "$plugin"
			return
		fi
	done

	if [[ -n $scope ]]; then
		printf "Unknown package source '%s' for %s or shared use\n" "$source" "$scope" >&2
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
		local function="source_$operation"
		declare -F "$function" >/dev/null || {
			printf "Package plugin '%s' does not support %s\n" "$plugin" "$operation" >&2
			return 1
		}
		"$function" "$@"
	)
}

_pkg_plugin_property() {
	local plugin=${1:?plugin path required}
	local property=${2:?property required}
	(
		set -Eeuo pipefail
		# shellcheck disable=SC1090
		source "$plugin"
		printf '%s\n' "${!property:-}"
	)
}

_pkg_validate_plugin_contract() {
	local plugin=${1:?plugin path required}
	shift
	(
		set -Eeuo pipefail
		# shellcheck disable=SC1090
		source "$plugin"
		local operation function
		for operation in "$@"; do
			function="source_$operation"
			declare -F "$function" >/dev/null || {
				printf "Package plugin '%s' does not implement %s\n" \
					"$plugin" "$function" >&2
				return 1
			}
		done
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
	_pkg_plugin_call "$plugin" prepare
}

pkg_source_prepare() {
	pkg_repo_enable "$@"
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

_pkg_validate_plan() {
	local plan=${1:?package plan required}
	local module_id module_dir spec selector plugin
	while IFS=$'\t' read -r module_id module_dir spec; do
		[[ -n $module_id && -n $module_dir && -n $spec ]] || {
			printf 'Malformed package-plan record: %q %q %q\n' \
				"$module_id" "$module_dir" "$spec" >&2
			return 1
		}
		if [[ $spec == source:* ]]; then
			selector=${spec#source:}
			_pkg_parse_source_selector "$selector" || return
			plugin=$(_pkg_plugin_path "$PKG_SCOPE" "$PKG_SOURCE" "$module_dir") || return
			_pkg_validate_plugin_contract "$plugin" prepare || return
			continue
		fi
		_pkg_parse_spec "$spec" || return
		if [[ $PKG_SOURCE != native ]]; then
			plugin=$(_pkg_plugin_path "$PKG_SCOPE" "$PKG_SOURCE" "$module_dir") || return
			_pkg_validate_plugin_contract "$plugin" prepare install is_installed remove || return
		fi
	done <"$plan"
}

# Apply the complete module package plan. Sources are prepared before the
# native transaction, and packages are deduplicated within each source group.
# Records are MODULE_ID<TAB>MODULE_DIR<TAB>SPEC. A source-only record prefixes
# the selector with "source:".
pkg_install_plan() {
	local plan=${1:?package plan required}
	[[ -f $plan ]] || {
		printf 'Package plan does not exist: %s\n' "$plan" >&2
		return 1
	}
	_pkg_validate_plan "$plan" || return

	local module_id module_dir spec plugin property recipe_root key index i package
	local native_packages=() group_keys=() group_plugins=() group_roots=() group_packages=()
	local prepared_plugins=()

	while IFS=$'\t' read -r module_id module_dir spec; do
		[[ -n $module_id && -n $module_dir && -n $spec ]] || {
			printf 'Malformed package-plan record: %q %q %q\n' \
				"$module_id" "$module_dir" "$spec" >&2
			return 1
		}
		if [[ $spec == source:* ]]; then
			_pkg_parse_source_selector "${spec#source:}" || return
			[[ -z $PKG_SCOPE || $PKG_SCOPE == "$DISTRO" ]] || continue
			plugin=$(_pkg_plugin_path "$PKG_SCOPE" "$PKG_SOURCE" "$module_dir") || return
			key="$plugin"$'\t'
			for ((i = 0; i < ${#group_keys[@]}; i++)); do
				[[ ${group_keys[$i]} != "$key" ]] || continue 2
			done
			group_keys+=("$key")
			group_plugins+=("$plugin")
			group_roots+=("")
			group_packages+=("")
			continue
		fi

		_pkg_parse_spec "$spec" || return
		_pkg_spec_applies || continue
		if [[ $PKG_SOURCE == native ]]; then
			for package in "${native_packages[@]}"; do
				[[ $package != "$PKG_NAME" ]] || continue 2
			done
			native_packages+=("$PKG_NAME")
			continue
		fi

		plugin=$(_pkg_plugin_path "$PKG_SCOPE" "$PKG_SOURCE" "$module_dir") || return
		recipe_root=
		property=$(_pkg_plugin_property "$plugin" source_uses_local_packages)
		if [[ $property == true ]]; then
			recipe_root="/run/$PROJECT_ID-package-recipes/$module_id"
			[[ -d $recipe_root ]] || {
				printf 'Module %s has no local packages directory for %s\n' \
					"$module_id" "$spec" >&2
				return 1
			}
		fi
		key="$plugin"$'\t'"$recipe_root"
		index=-1
		for ((i = 0; i < ${#group_keys[@]}; i++)); do
			if [[ ${group_keys[$i]} == "$key" ]]; then
				index=$i
				break
			fi
		done
		if ((index < 0)); then
			index=${#group_keys[@]}
			group_keys+=("$key")
			group_plugins+=("$plugin")
			group_roots+=("$recipe_root")
			group_packages+=("")
		fi
		if [[ $'\n'${group_packages[$index]} != *$'\n'"$PKG_NAME"$'\n'* ]]; then
			group_packages[$index]+="$PKG_NAME"$'\n'
		fi
	done <"$plan"

	for plugin in "${group_plugins[@]}"; do
		for key in "${prepared_plugins[@]}"; do
			[[ $key != "$plugin" ]] || continue 2
		done
		printf 'Preparing package source: %s\n' "${plugin#"$SETUP_ROOT/"}"
		_pkg_plugin_call "$plugin" prepare
		prepared_plugins+=("$plugin")
	done

	if ((${#native_packages[@]} > 0)); then
		printf 'Installing %d native packages\n' "${#native_packages[@]}"
		pkg_native_install "${native_packages[@]}"
	fi

	local packages=()
	for ((index = 0; index < ${#group_plugins[@]}; index++)); do
		[[ -n ${group_packages[$index]} ]] || continue
		mapfile -t packages <<<"${group_packages[$index]%$'\n'}"
		printf 'Installing %d packages from source: %s\n' \
			"${#packages[@]}" "${group_plugins[$index]#"$SETUP_ROOT/"}"
		PACKAGE_RECIPE_ROOT=${group_roots[$index]} \
			_pkg_plugin_call "${group_plugins[$index]}" install "${packages[@]}"
	done
}
