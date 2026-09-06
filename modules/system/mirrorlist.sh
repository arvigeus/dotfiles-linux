#!/usr/bin/env bash
## Arch package maintenance
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:pkgstats
	arch:pacman-contrib
	arch:reflector
)

module_apply() {
	[[ $DISTRO == arch ]] || return 0
	file_write /etc/xdg/reflector/reflector.conf <<'EOF'
--latest 50
--protocol https
--sort rate
--age 24
--save /etc/pacman.d/mirrorlist
EOF

	systemctl enable reflector.timer
	# Do not run Reflector from a pacman-mirrorlist hook: the weekly timer avoids
	# an unnecessary mirror benchmark for infrequent mirrorlist package updates.
}

module_entrypoint "$@"
