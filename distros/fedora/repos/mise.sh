#!/usr/bin/env bash

repo_enable() (
	[[ -f /etc/yum.repos.d/mise.repo ]] && return 0

	local tmpdir
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	curl --fail --silent --show-error --location \
		--output "$tmpdir/mise.repo" \
		https://mise.jdx.dev/rpm/mise.repo
	file_write /etc/yum.repos.d/mise.repo <"$tmpdir/mise.repo"
)

repo_install() {
	repo_enable
	pkg_native_install "$@"
}

repo_is_installed() {
	pkg_native_is_installed "$1"
}
