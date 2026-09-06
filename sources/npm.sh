#!/usr/bin/env bash

source_prepare() {
	case $DISTRO in
	arch) pkg_install arch:extra/nodejs arch:extra/npm ;;
	fedora) pkg_install nodejs npm ;;
	esac
}

source_install() {
	source_prepare
	# Neither Codex nor Pi requires lifecycle scripts for its published CLI.
	npm install --global --ignore-scripts -- "$@"
}

source_is_installed() {
	npm list --global --depth=0 -- "$1" >/dev/null 2>&1
}

source_remove() {
	npm uninstall --global -- "$@"
}
