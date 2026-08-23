#!/usr/bin/env bash

# shellcheck source=lib/github.sh
source "$SETUP_ROOT/lib/github.sh"
[[ ${DISTRO:-} == arch || ${DISTRO:-} == fedora ]] || {
	printf 'Unsupported or missing module DISTRO: %s\n' "${DISTRO:-unset}" >&2
	return 1 2>/dev/null || exit 1
}
# shellcheck disable=SC1090
source "$SETUP_ROOT/distros/$DISTRO/distro.sh"
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

# Run a build function with temporary packages, then remove only requested
# build dependencies that were not present beforehand.
pkg_from_source() {
	local build_function=${1:?pkg_from_source requires a build function}
	shift

	local package
	local added_packages=()
	for package in "$@"; do
		pkg_is_installed "$package" || added_packages+=("$package")
	done

	((${#added_packages[@]} == 0)) || pkg_install "${added_packages[@]}"

	local build_status=0 cleanup_status=0 restore_errexit=false
	[[ $- == *e* ]] && restore_errexit=true
	set +e
	(
		set -e
		"$build_function"
	)
	build_status=$?
	[[ $restore_errexit == false ]] || set -e

	if ((${#added_packages[@]} > 0)); then
		pkg_native_remove "${added_packages[@]}" || cleanup_status=$?
	fi

	((build_status == 0)) || return "$build_status"
	return "$cleanup_status"
}

# Atomically replace a file with stdin. The existing mode is retained unless a
# mode is supplied as the second argument.
file_write() {
	local destination=${1:?file_write requires a destination}
	local mode=${2:-}
	local temporary="${destination}.${PROJECT_ID}-tmp"

	mkdir -p "$(dirname -- "$destination")"
	[[ -n $mode ]] || mode=$([[ -e $destination ]] && stat -c %a "$destination" || printf '0644')
	cat >"$temporary"
	chmod "$mode" "$temporary"
	mv -Tf -- "$temporary" "$destination"
}

# Atomically append stdin to a file. Rebuilding a fresh root prevents content
# from accumulating between generations.
file_append() {
	local destination=${1:?file_append requires a destination}
	local mode=${2:-}
	local temporary="${destination}.${PROJECT_ID}-tmp"

	mkdir -p "$(dirname -- "$destination")"
	[[ -n $mode ]] || mode=$([[ -e $destination ]] && stat -c %a "$destination" || printf '0644')
	if [[ -e $destination ]]; then
		cat -- "$destination" >"$temporary"
	else
		: >"$temporary"
	fi
	cat >>"$temporary"
	chmod "$mode" "$temporary"
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
