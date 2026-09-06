#!/usr/bin/env bash

_dnf_set_option() {
	local config=${1:?configuration required}
	local key=${2:?key required}
	local value=${3:?value required}
	if grep -Eq "^[#;[:space:]]*${key}[[:space:]]*=" "$config"; then
		sed -i -E "s|^[#;[:space:]]*${key}[[:space:]]*=.*|$key=$value|" "$config"
	else
		sed -i "/^\[main\]$/a $key=$value" "$config"
	fi
}

pkg_native_configure() {
	local root=${1:-}
	local config="$root/etc/dnf/dnf.conf"
	[[ -f $config ]] || {
		printf 'DNF configuration not found: %s\n' "$config" >&2
		return 1
	}
	grep -q '^\[main\]$' "$config" || printf '\n[main]\n' >>"$config"

	_dnf_set_option "$config" minrate 100k
	_dnf_set_option "$config" timeout 15
	_dnf_set_option "$config" retries 10
	_dnf_set_option "$config" fastestmirror True
	_dnf_set_option "$config" max_parallel_downloads 10
}

pkg_native_install() {
	dnf -y install "$@"
}

pkg_native_is_installed() {
	rpm -q -- "$1" >/dev/null 2>&1
}

pkg_native_remove() {
	dnf -y remove --no-autoremove "$@"
}
