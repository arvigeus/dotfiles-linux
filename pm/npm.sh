#!/usr/bin/env bash

pm_enable() {
	pkg_install nodejs npm
}

pm_install() {
	pm_enable
	# Neither Codex nor Pi requires lifecycle scripts for its published CLI.
	npm install --global --ignore-scripts -- "$@"
}

pm_is_installed() {
	npm list --global --depth=0 -- "$1" >/dev/null 2>&1
}

pm_remove() {
	npm uninstall --global -- "$@"
}
