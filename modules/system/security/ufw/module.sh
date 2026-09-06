#!/usr/bin/env bash
## Uncomplicated firewall — persistent default-deny baseline
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(ufw)

# Do not invoke ufw against the build host's kernel. The packaged defaults are
# edited offline; feature-owned rules are applied serially during boot.
module_apply() {
	sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
	sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/' /etc/default/ufw
	sed -i 's/^DEFAULT_OUTPUT_POLICY=.*/DEFAULT_OUTPUT_POLICY="ACCEPT"/' /etc/default/ufw
	systemctl enable ufw.service system-ufw-rules.service
}

module_entrypoint "$@"
