#!/usr/bin/env bash
## libvirt desktop virtualization tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

requires=(system/security/ufw)

packages=(
	virt-manager
	arch:libvirt
	fedora:libvirt-daemon-kvm
	arch:qemu-desktop
	fedora:qemu-kvm
	dnsmasq
)

module_apply() {
	file_write /etc/sysctl.d/99-libvirt.conf <<'EOF'
net.ipv4.ip_forward=1
EOF
	systemctl enable libvirtd.service
}

module_entrypoint "$@"
