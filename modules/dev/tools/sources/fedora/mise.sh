#!/usr/bin/env bash

source_prepare() (
	[[ -f /etc/yum.repos.d/mise.repo ]] && return 0

	local tmpdir
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	curl --fail --silent --show-error --location \
		--connect-timeout 20 --max-time 120 --retry 3 --retry-all-errors \
		--output "$tmpdir/mise.repo" \
		https://mise.jdx.dev/rpm/mise.repo
	file_write /etc/yum.repos.d/mise.repo <"$tmpdir/mise.repo"
)

source_install() {
	source_prepare
	dnf -y install --from-repo=mise "$@"
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
