#!/usr/bin/env bash

pm_enable() (
	[[ -f /etc/yum.repos.d/vscode.repo ]] && return 0

	local tmpdir
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	curl --fail --silent --show-error --location \
		--output "$tmpdir/microsoft.asc" \
		https://packages.microsoft.com/keys/microsoft.asc
	rpm --import "$tmpdir/microsoft.asc"
	file_write /etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
)

pm_install() {
	pm_enable
	dnf -y install --from-repo=code "$@"
}

pm_is_installed() {
	pkg_native_is_installed "$1"
}

pm_remove() {
	pkg_native_remove "$@"
}
