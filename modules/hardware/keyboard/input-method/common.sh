#!/usr/bin/env bash
## Shared on-demand input controller; no Fcitx dependency or startup.
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
module_check() { [[ ${DESKTOP:-} == plasma || ${DESKTOP:-} == hyprland ]]; }
packages=(bash coreutils util-linux gawk jq glib2)
module_apply() {
	file_write -m 0755 /usr/local/bin/system-input-method <"$MODULE_DIR/system-input-method"
}
module_entrypoint "$@"
