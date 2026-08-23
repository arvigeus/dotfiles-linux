#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

pkg_install sudo
install -d -m 0750 /etc/sudoers.d
printf '%s ALL=(ALL:ALL) ALL\n' "$USERNAME" >"/etc/sudoers.d/10-$USERNAME"
chmod 0440 "/etc/sudoers.d/10-$USERNAME"
visudo --check --file "/etc/sudoers.d/10-$USERNAME"
