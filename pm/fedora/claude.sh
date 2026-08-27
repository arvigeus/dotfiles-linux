#!/usr/bin/env bash

_claude_package_name() {
	case ${1:?Claude package required} in
	claude) printf 'claude-code\n' ;;
	*)
		printf 'Unknown Claude package: %s\n' "$1" >&2
		return 1
		;;
	esac
}

pm_enable() {
	[[ -f /etc/yum.repos.d/claude-code.repo ]] && return 0

	# Anthropic stable RPM channel; DNF imports its published signing key.
	file_write /etc/yum.repos.d/claude-code.repo <<'REPO'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
REPO
}

pm_install() {
	pm_enable
	local package native_packages=()
	for package in "$@"; do
		native_packages+=("$(_claude_package_name "$package")")
	done
	dnf -y install --from-repo=claude-code "${native_packages[@]}"
}

pm_is_installed() {
	local package
	package=$(_claude_package_name "$1") || return
	pkg_native_is_installed "$package"
}

pm_remove() {
	local package native_packages=()
	for package in "$@"; do
		native_packages+=("$(_claude_package_name "$package")")
	done
	pkg_native_remove "${native_packages[@]}"
}
