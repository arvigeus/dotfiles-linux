#!/usr/bin/env bash

# shellcheck source=lib/github.sh
source "$SETUP_ROOT/lib/github.sh"
[[ ${DISTRO:-} == arch || ${DISTRO:-} == fedora ]] || {
	printf 'Unsupported or missing module DISTRO: %s\n' "${DISTRO:-unset}" >&2
	return 1 2>/dev/null || exit 1
}
# shellcheck disable=SC1090
source "$SETUP_ROOT/pm/$DISTRO/$PACKAGE_MANAGER.sh"
# shellcheck source=lib/package.sh
source "$SETUP_ROOT/lib/package.sh"

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
