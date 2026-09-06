#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

packages=(
	sudo
)

module_apply() {
	install -d -m 0750 /etc/sudoers.d
	# The encrypted boot and lock screen remain the authentication boundaries;
	# interactive sudo is deliberately passwordless for this personal workstation.
	printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$USERNAME" >"/etc/sudoers.d/10-$USERNAME"
	chmod 0440 "/etc/sudoers.d/10-$USERNAME"
	visudo --check --file "/etc/sudoers.d/10-$USERNAME"

	# "please" — polite alias for sudo
	shell_set_alias sudo please sudo
}

module_entrypoint "$@"
