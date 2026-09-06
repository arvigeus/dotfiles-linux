#!/usr/bin/env bash
## Optional OpenSSH server; deliberately soft-disabled for this workstation
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

module_check() {
	return 1
}

requires=(system/security/ufw)
packages=(
	arch:openssh
	fedora:openssh-server
)

module_apply() {
	systemctl enable sshd.service
	preserve_path '/etc/ssh/ssh_host_*'
}

module_entrypoint "$@"
