#!/usr/bin/env bash
## Pi coding agent
## https://pi.dev/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:extra/nodejs
	arch:extra/npm
	arch:aur/pi-coding-agent
	fedora:npm/@earendil-works/pi-coding-agent
	arch:python
	fedora:python3
	arch:pacman-contrib
	fedora:dnf-plugins-core
)

module_apply() {
	local destination="$HOME/.pi/agent/extensions/system-update"
	install -d -m 0755 "$destination"
	install -m 0644 "$MODULE_DIR/plugins/system-update/index.ts" "$destination/index.ts"
	install -m 0644 "$MODULE_DIR/plugins/system-update/backend.py" "$destination/backend.py"
}

module_healthcheck() {
	command -v pi >/dev/null
	command -v python3 >/dev/null
	[[ -f $HOME/.pi/agent/extensions/system-update/index.ts ]]
	[[ -f $HOME/.pi/agent/extensions/system-update/backend.py ]]
	if [[ $DISTRO == arch ]]; then
		command -v checkupdates >/dev/null
	else
		dnf repoquery --help >/dev/null
	fi
}

module_entrypoint "$@"
