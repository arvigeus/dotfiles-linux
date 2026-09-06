#!/usr/bin/env bash
## Firmware update daemon (metadata refresh only during provisioning)
## https://fwupd.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(fwupd)

module_apply() {
	systemctl enable fwupd-refresh.timer
}

# Firmware updates are deliberately not executed against the build host's
# hardware or from a pacman hook. Run `fwupdmgr update` manually on the booted
# target so firmware changes remain an explicit, physical-machine action.
module_entrypoint "$@"
