#!/usr/bin/env bash
## Uncomplicated firewall — persistent default-deny baseline
## https://wiki.archlinux.org/title/Uncomplicated_Firewall
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

pkg_install ufw

# Do not invoke ufw against the build host's kernel. The packaged defaults are
# DROP incoming and ACCEPT outgoing; enabling the unit applies them at boot.
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/' /etc/default/ufw
sed -i 's/^DEFAULT_OUTPUT_POLICY=.*/DEFAULT_OUTPUT_POLICY="ACCEPT"/' /etc/default/ufw
systemctl enable ufw.service
