#!/usr/bin/env bash
source "$SETUP_ROOT/lib/env.sh"

_FLATPAK_READY=false

# Modules normally use /etc/skel as HOME so they can write login defaults.
# Flatpak cannot expose a home below its reserved /etc tree to apply_extra
# sandboxes, so give each invocation a short-lived home below /home instead.
_flatpak_command() (
	local home_parent=${_FLATPAK_HOME_PARENT:-/home} temporary_home
	temporary_home=$(mktemp -d "$home_parent/.system-flatpak.XXXXXX")
	trap 'rm -rf -- "$temporary_home"' EXIT
	HOME=$temporary_home \
		XDG_CONFIG_HOME="$temporary_home/.config" \
		XDG_DATA_HOME="$temporary_home/.local/share" \
		XDG_STATE_HOME="$temporary_home/.local/state" \
		XDG_CACHE_HOME="$temporary_home/.cache" \
		flatpak "$@"
)

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
	_flatpak_command --system remote-add --if-not-exists "$name" "$url"
}

# Install refs directly into the candidate's system-wide installation. Running
# as root bypasses flatpak-system-helper, so no D-Bus session or bus is needed.
flatpak_install() {
	local remote=${1:?remote name required}
	shift
	flatpak_prepare
	_flatpak_command install --system -y --noninteractive "$remote" "$@"
}

# Apply an override to the candidate's system-wide Flatpak installation.
flatpak_override() {
	_flatpak_command override --system "$@"
}

flatpak_alias() {
	local name=${1:?alias name required} app_id=${2:?application ID required}
	shift 2
	shell_set_alias flatpak "$name" "flatpak run $app_id${*:+ $*}"
}
