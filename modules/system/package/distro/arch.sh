#!/usr/bin/env bash
## Arch package-manager configuration
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
[[ $DISTRO == arch ]] || exit 0

# The clean base has one canonical pacman.conf, so direct edits are safe.
sed -i '/^\[options\]/a ParallelDownloads = 10\nVerbosePkgLists' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

pkg_install pkgstats pacman-contrib reflector

file_write /etc/xdg/reflector/reflector.conf <<'EOF'
--latest 50
--protocol https
--sort rate
--age 24
--save /etc/pacman.d/mirrorlist
EOF
systemctl enable reflector.timer
