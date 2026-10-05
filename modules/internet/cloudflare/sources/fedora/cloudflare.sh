#!/usr/bin/env bash

source_prepare() (
	local tmpdir
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	curl --fail --silent --show-error --location \
		--connect-timeout 20 --max-time 120 --retry 3 --retry-all-errors \
		--output "$tmpdir/pubkey.gpg" https://pkg.cloudflareclient.com/pubkey.gpg
	rpm --import "$tmpdir/pubkey.gpg"
	file_write /etc/yum.repos.d/cloudflare-warp.repo <<'REPO'
[cloudflare-warp-stable]
name=cloudflare-warp-stable
baseurl=https://pkg.cloudflareclient.com/rpm
enabled=1
type=rpm
gpgcheck=1
gpgkey=https://pkg.cloudflareclient.com/pubkey.gpg
REPO
)

source_install() {
	source_prepare
	dnf -y install --from-repo=cloudflare-warp-stable "$@"
}
source_is_installed() { pkg_native_is_installed "$1"; }
source_remove() { pkg_native_remove "$@"; }
