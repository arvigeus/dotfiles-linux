#!/usr/bin/env bash
## Firmware update daemon (metadata refresh only during provisioning)
## https://fwupd.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

pkg_install fwupd
systemctl enable fwupd-refresh.timer

# Firmware updates are deliberately not executed against the build host's
# hardware. Run `fwupdmgr update` manually on the booted target.
