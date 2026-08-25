#!/usr/bin/env bash

pacman_repo_write() (
	set -Eeuo pipefail
	local section=${1:?repository section required}
	local before=${2:-}
	local config=${PACMAN_CONFIG:-/etc/pacman.conf}
	[[ $section =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
		printf 'Invalid Pacman repository section: %s\n' "$section" >&2
		return 1
	}
	[[ -z $before || $before =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
		printf 'Invalid Pacman repository ordering target: %s\n' "$before" >&2
		return 1
	}
	[[ -f $config ]] || {
		printf 'Pacman configuration not found: %s\n' "$config" >&2
		return 1
	}

	local block output
	block=$(mktemp)
	output=$(mktemp)
	trap 'rm -f -- "$block" "$output"' EXIT
	{
		printf '[%s]\n' "$section"
		command cat
	} >"$block"

	awk -v section="$section" -v before="$before" -v block="$block" '
		function emit( line) {
			if (written) return
			if (printed && !last_blank) print ""
			while ((getline line < block) > 0) {
				print line
				last_blank = (line == "")
			}
			close(block)
			if (!last_blank) print ""
			written = printed = last_blank = 1
		}
		/^\[[^]]+\]$/ {
			current = substr($0, 2, length($0) - 2)
			if (current == section) {
				if (before == "") emit()
				skipping = 1
				next
			}
			if (before != "" && current == before) emit()
			skipping = 0
		}
		!skipping {
			print
			printed = 1
			last_blank = ($0 == "")
		}
		END { if (!written) emit() }
	' "$config" >"$output"
	cmp -s "$output" "$config" && return 1
	command cat "$output" >"$config"
)

pkg_native_configure() {
	local root=${1:-}
	local config="$root/etc/pacman.conf"
	[[ -f $config ]] || {
		printf 'Pacman configuration not found: %s\n' "$config" >&2
		return 1
	}

	if grep -Eq '^[#[:space:]]*ParallelDownloads([[:space:]]*=|[[:space:]]*$)' "$config"; then
		sed -i -E 's/^[#[:space:]]*ParallelDownloads([[:space:]]*=.*)?$/ParallelDownloads = 10/' "$config"
	else
		sed -i '/^\[options\]$/a ParallelDownloads = 10' "$config"
	fi
	if grep -Eq '^[#[:space:]]*VerbosePkgLists([[:space:]]*$)' "$config"; then
		sed -i -E 's/^[#[:space:]]*VerbosePkgLists[[:space:]]*$/VerbosePkgLists/' "$config"
	else
		sed -i '/^\[options\]$/a VerbosePkgLists' "$config"
	fi
}

pkg_native_install() {
	pacman -S --needed --noconfirm -- "$@"
}

pkg_native_is_installed() {
	pacman -Qq -- "$1" >/dev/null 2>&1
}

pkg_native_remove() {
	pacman -Rns --noconfirm -- "$@"
}
