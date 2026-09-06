#!/usr/bin/env bash

# shellcheck source=lib/github.sh
source "$SETUP_ROOT/lib/github.sh"
[[ ${DISTRO:-} == arch || ${DISTRO:-} == fedora ]] || {
	printf 'Unsupported or missing module DISTRO: %s\n' "${DISTRO:-unset}" >&2
	return 1 2>/dev/null || exit 1
}
# shellcheck disable=SC1090
source "$SETUP_ROOT/sources/$DISTRO/$PACKAGE_MANAGER.sh"
# shellcheck source=lib/package.sh
source "$SETUP_ROOT/lib/package.sh"

# A module is evaluated once to emit a mutation-free plan and once, after all
# packages are present, to apply configuration. Arrays are the public data
# format; callers never source multiple modules into one shell.
_module_emit_array() {
	local record_type=${1:?record type required}
	local array_name=${2:?array name required}
	declare -p "$array_name" >/dev/null 2>&1 || return 0
	local -n values=$array_name
	local value
	for value in "${values[@]}"; do
		[[ -n $value && $value != *$'\t'* && $value != *$'\n'* ]] || {
			printf 'Invalid %s declaration in %s: %q\n' \
				"$record_type" "${MODULE_ID:-unknown}" "$value" >&2
			return 1
		}
		printf '%s\t%s\n' "$record_type" "$value" >>"$MODULE_PLAN_FILE"
	done
}

module_entrypoint() {
	local phase=${MODULE_PHASE:?MODULE_PHASE is required}
	case $phase in
	plan)
		: "${MODULE_PLAN_FILE:?MODULE_PLAN_FILE is required}"
		: >"$MODULE_PLAN_FILE"
		if declare -F module_check >/dev/null && ! module_check; then
			printf 'skip\tmodule check did not match\n' >>"$MODULE_PLAN_FILE"
			return 0
		fi

		local has_members=false
		# shellcheck disable=SC2154 # optional public module declaration
		if declare -p members >/dev/null 2>&1; then
			local -n module_members=members
			((${#module_members[@]} == 0)) || has_members=true
		fi
		if [[ $has_members == true ]]; then
			local declaration
			for declaration in packages sources requires; do
				if declare -p "$declaration" >/dev/null 2>&1; then
					printf 'Aggregate module %s also declares %s\n' \
						"${MODULE_ID:-unknown}" "$declaration" >&2
					return 1
				fi
			done
			if declare -F module_apply >/dev/null; then
				printf 'Aggregate module %s must contain only members\n' \
					"${MODULE_ID:-unknown}" >&2
				return 1
			fi
			_module_emit_array member members
			return
		fi

		printf 'leaf\t%s\n' "${MODULE_ID:-unknown}" >>"$MODULE_PLAN_FILE"
		_module_emit_array require requires
		_module_emit_array source sources
		_module_emit_array package packages
		;;
	apply)
		if declare -F module_check >/dev/null && ! module_check; then
			printf 'Module check changed after planning: %s\n' \
				"${MODULE_ID:-unknown}" >&2
			return 1
		fi
		if [[ -d $MODULE_DIR/files ]]; then
			cp -a --no-preserve=ownership -- \
				"$MODULE_DIR/files/." "${MODULE_ROOT:-/}"
		fi
		if declare -F module_apply >/dev/null; then
			module_apply
		fi
		;;
	healthcheck)
		if declare -F module_check >/dev/null && ! module_check; then
			return 0
		fi
		if declare -F module_healthcheck >/dev/null; then
			module_healthcheck
		fi
		;;
	*)
		printf 'Unknown module phase: %s\n' "$phase" >&2
		return 1
		;;
	esac
}

# Request that machine-local state be copied from the active root after all
# modules finish. Globs are expanded by the host, not inside the candidate.
preserve_path() {
	(($# > 0)) || {
		printf 'preserve_path requires at least one path\n' >&2
		return 1
	}
	: "${PRESERVE_REQUESTS_FILE:?PRESERVE_REQUESTS_FILE is required}"

	local path
	for path in "$@"; do
		[[ $path == /* && $path != / && $path != *$'\n'* ]] || {
			printf 'Invalid preserved path: %q\n' "$path" >&2
			return 1
		}
		[[ $path != /.. && $path != /../* && $path != */../* && $path != */.. ]] || {
			printf 'Preserved path escapes the root: %q\n' "$path" >&2
			return 1
		}
		printf '%s\n' "$path" >>"$PRESERVE_REQUESTS_FILE"
	done
}

# Register an override for a path written below $HOME (/etc/skel during builds).
# Usage: home_strategy .config/app/settings.json json unchanged
home_strategy() {
	local path=${1:?home_strategy requires a path}
	local strategy=${2:-auto}
	local delete_mode=${3:-${HOME_DELETE_MODE:-unchanged}}

	path=${path#"${HOME:-/etc/skel}/"}
	path=${path#/}
	[[ -n $path && $path != *$'\t'* && $path != *$'\n'* ]] || {
		printf 'Invalid home strategy path: %q\n' "$path" >&2
		return 1
	}
	[[ $path != .. && $path != ../* && $path != */../* ]] || {
		printf 'Home strategy path escapes HOME: %q\n' "$path" >&2
		return 1
	}

	mkdir -p "/etc/$PROJECT_ID"
	printf '%s\t%s\t%s\n' "$path" "$strategy" "$delete_mode" \
		>>"/etc/$PROJECT_ID/home-strategies.tsv"
}

# Parse install-style metadata flags for file_write and file_append.
_file_parse_options() {
	FILE_MODE=
	FILE_OWNER=
	FILE_GROUP=
	FILE_DESTINATION=

	while (($# > 0)); do
		case $1 in
		-m | --mode)
			(($# >= 2)) || {
				printf '%s requires a value\n' "$1" >&2
				return 1
			}
			FILE_MODE=$2
			shift 2
			;;
		-o | --owner)
			(($# >= 2)) || {
				printf '%s requires a value\n' "$1" >&2
				return 1
			}
			FILE_OWNER=$2
			shift 2
			;;
		-g | --group)
			(($# >= 2)) || {
				printf '%s requires a value\n' "$1" >&2
				return 1
			}
			FILE_GROUP=$2
			shift 2
			;;
		--)
			shift
			break
			;;
		-*)
			printf 'Unknown file option: %s\n' "$1" >&2
			return 1
			;;
		*) break ;;
		esac
	done

	(($# == 1)) || {
		printf 'Exactly one destination is required\n' >&2
		return 1
	}
	FILE_DESTINATION=$1

	if [[ -e $FILE_DESTINATION || -L $FILE_DESTINATION ]]; then
		[[ -n $FILE_MODE ]] || FILE_MODE=$(stat -c %a -- "$FILE_DESTINATION")
		[[ -n $FILE_OWNER ]] || FILE_OWNER=$(stat -c %u -- "$FILE_DESTINATION")
		[[ -n $FILE_GROUP ]] || FILE_GROUP=$(stat -c %g -- "$FILE_DESTINATION")
	else
		FILE_MODE=${FILE_MODE:-0644}
		FILE_OWNER=${FILE_OWNER:-root}
		FILE_GROUP=${FILE_GROUP:-root}
	fi
}

# Atomically replace a file with stdin.
# Usage: file_write [-m MODE] [-o OWNER] [-g GROUP] DESTINATION
file_write() {
	_file_parse_options "$@" || return
	local destination=$FILE_DESTINATION
	local temporary="${destination}.${PROJECT_ID}-tmp"

	mkdir -p "$(dirname -- "$destination")"
	rm -f -- "$temporary"
	cat >"$temporary"
	chmod "$FILE_MODE" "$temporary"
	chown "$FILE_OWNER:$FILE_GROUP" "$temporary"
	mv -Tf -- "$temporary" "$destination"
}

# Atomically append stdin to a file. Rebuilding a fresh root prevents content
# from accumulating between generations.
# Usage: file_append [-m MODE] [-o OWNER] [-g GROUP] DESTINATION
file_append() {
	_file_parse_options "$@" || return
	local destination=$FILE_DESTINATION
	local temporary="${destination}.${PROJECT_ID}-tmp"

	mkdir -p "$(dirname -- "$destination")"
	rm -f -- "$temporary"
	if [[ -e $destination || -L $destination ]]; then
		cat -- "$destination" >"$temporary"
	else
		: >"$temporary"
	fi
	cat >>"$temporary"
	chmod "$FILE_MODE" "$temporary"
	chown "$FILE_OWNER:$FILE_GROUP" "$temporary"
	mv -Tf -- "$temporary" "$destination"
}

# Replace a complete directory tree. Useful for downloaded plugins and other
# opaque trees where stale files must not survive.
file_install_tree() {
	local source=${1:?file_install_tree requires a source directory}
	local destination=${2:?file_install_tree requires a destination directory}
	local mode=${3:-0755}

	[[ -d $source ]] || {
		printf 'Source tree does not exist: %s\n' "$source" >&2
		return 1
	}
	rm -rf -- "$destination"
	install -d -m "$mode" "$destination"
	cp -a --no-preserve=ownership -- "$source/." "$destination/"
	chmod "$mode" "$destination"
}
