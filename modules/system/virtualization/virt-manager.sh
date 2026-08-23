#!/usr/bin/env bash
## libvirt desktop virtualization tools
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	virt-manager
    arch:libvirt
    fedora:libvirt-daemon-kvm
    arch:qemu-desktop
    fedora:qemu-kvm
    arch:dnsmasq
)
pkg_install "${packages[@]}"


file_write /etc/sysctl.d/99-libvirt.conf <<'EOF'
net.ipv4.ip_forward=1
EOF
systemctl enable libvirtd.service

# Interface-specific UFW rules were omitted: the previous wlan0 assumption is
# not portable and firewall commands must not probe the build host's kernel.
