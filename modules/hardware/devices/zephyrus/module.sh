#!/usr/bin/env bash
## ASUS ROG Zephyrus platform support
## https://asus-linux.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

module_check() {
	dmi_matches asus && { dmi_matches zephyrus || dmi_matches rog; }
}

packages=(
	# The base system already supplies linux-firmware. These additional firmware
	# blobs came from the prior GA402 setup; Fedora equivalents are intentionally
	# not guessed.
	arch:linux-firmware-qlogic
	arch:aur/aic94xx-firmware
	arch:aur/ast-firmware
	arch:aur/upd72020x-fw
	arch:aur/wd719x-firmware

	arch:ogc/asusctl
	fedora:terra/asusctl

	arch:ogc/rog-control-center
	fedora:terra/asusctl-rog-gui

	arch:switcheroo-control
	fedora:switcheroo-control
)
module_apply() {

	# asusd is the sole platform-profile and CPU-EPP owner. ASUS upstream warns
	# that PPD or tuned running at the same time races on those same interfaces;
	# masks also prevent desktop D-Bus activation from starting them later.
	for service in \
		power-profiles-daemon.service \
		tuned.service \
		tuned-ppd.service; do
		systemctl disable "$service" 2>/dev/null || true
		systemctl mask "$service"
	done

	systemctl enable \
		asusd.service \
		asus-shutdown.service \
		switcheroo-control.service

	# Prefer the RX 6800S when firmware exposes it. The session launcher falls back
	# to automatic GPU selection in integrated mode, where the device is absent.
	if dmi_matches ga402; then
		file_write /etc/system/gaming-session.conf <<'EOF'
# AMD Radeon RX 6800S (GA402RK). Use "auto" to prefer the active boot GPU.
SYSTEM_GAMING_GPU=1002:73ef
EOF
	fi
}

module_entrypoint "$@"
