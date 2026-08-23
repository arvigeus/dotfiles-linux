#!/usr/bin/env bash
source "$SETUP_ROOT/lib/env.sh"

_FLATPAK_READY=false

flatpak_prepare() {
	[[ $_FLATPAK_READY == false ]] || return 0

	pkg_is_installed flatpak || pkg_install flatpak
	_FLATPAK_READY=true
}

# Register a signed remote in the candidate's system-wide Flatpak installation.
# Modules run as root inside the candidate, so Flatpak writes directly without
# requiring a running system bus or privileged helper.
flatpak_remote_add() {
	local name=${1:?remote name required}
	local url=${2:?remote URL required}
	flatpak --system remote-add --if-not-exists "$name" "$url"
}

# Install refs directly into the candidate's system-wide installation. Running
# as root bypasses flatpak-system-helper, so no D-Bus session or bus is needed.
flatpak_install() {
	local remote=${1:?remote name required}
	shift
	flatpak_prepare
	flatpak install --system -y --noninteractive "$remote" "$@"
}

flatpak_alias() {
	local name=${1:?alias name required} app_id=${2:?application ID required}
	shift 2
	shell_set_alias flatpak "$name" "flatpak run $app_id${*:+ $*}"
}
