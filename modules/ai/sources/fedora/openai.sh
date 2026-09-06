#!/usr/bin/env bash

source_prepare() {
	# The official bootstrap RPM installs OpenAI's signed DNF repository.
	:
}

_openai_install_chatgpt() (
	set -Eeuo pipefail
	pkg_native_is_installed chatgpt && return 0

	local architecture package_url tmpdir rpm
	architecture=$(uname -m)
	case $architecture in
	x86_64) package_url=https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm ;;
	aarch64) package_url=https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.aarch64.rpm ;;
	*)
		printf 'Unsupported ChatGPT desktop architecture: %s\n' "$architecture" >&2
		return 1
		;;
	esac

	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	rpm="$tmpdir/chatgpt.rpm"
	curl --fail --silent --show-error --location \
		--connect-timeout 20 --max-time 300 --retry 3 --retry-all-errors \
		--output "$rpm" "$package_url"
	pkg_native_install "$rpm"
)

source_install() {
	source_prepare
	local package
	for package in "$@"; do
		case $package in
		chatgpt) _openai_install_chatgpt ;;
		*)
			printf 'Unknown OpenAI package: %s\n' "$package" >&2
			return 1
			;;
		esac
	done
}

source_is_installed() {
	case ${1:?OpenAI package required} in
	chatgpt) pkg_native_is_installed chatgpt ;;
	*) return 1 ;;
	esac
}

source_remove() {
	local package native_packages=()
	for package in "$@"; do
		case $package in
		chatgpt) native_packages+=(chatgpt) ;;
		*)
			printf 'Unknown OpenAI package: %s\n' "$package" >&2
			return 1
			;;
		esac
	done
	pkg_native_remove "${native_packages[@]}"
}
