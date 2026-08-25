#!/usr/bin/env bash
## Arch package maintenance
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

if [[ $DISTRO == arch ]]; then
  pkg_install pkgstats pacman-contrib reflector

  file_write /etc/xdg/reflector/reflector.conf <<'EOF'
--latest 50
--protocol https
--sort rate
--age 24
--save /etc/pacman.d/mirrorlist
EOF

  systemctl enable reflector.timer
fi
