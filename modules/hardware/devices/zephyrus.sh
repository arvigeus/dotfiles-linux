#!/usr/bin/env bash
## ASUS ROG Zephyrus platform support
## https://asus-linux.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

dmi_matches asus || exit 0
dmi_matches zephyrus || dmi_matches 'rog' || exit 0

case "$DISTRO" in
arch)
	# The managed kernel is linux-ogc. Do not replace it opportunistically with
	# linux-g14 in this hardware-specific module and desynchronize the UKI.
	if pkg_native_is_installed switcheroo-control; then
		pkg_native_remove switcheroo-control
	fi
	pkg_install \
		arch:ogc/asusctl \
		arch:ogc/rog-control-center \
		arch:power-profiles-daemon \
		arch:ogc/cardwire
	;;
fedora)
	if pkg_is_installed tuned-ppd; then
		dnf -y swap --allowerasing tuned-ppd power-profiles-daemon
	else
		pkg_install power-profiles-daemon
	fi
	pkg_install fedora:terra/asusctl fedora:terra/asusctl-rog-gui
	if pkg_native_is_installed switcheroo-control; then
		dnf -y swap --allowerasing switcheroo-control cardwire
	else
		pkg_install fedora:terra/cardwire
	fi
	pkg_install fedora:terra/cardwire-gui
	;;
esac

systemctl enable \
	asusd.service \
	cardwired.service \
	power-profiles-daemon.service

# GA402RK-L8149 has a 2560x1600 120 Hz Adaptive-Sync panel and an RX 6800S.
# Scope these values to the Gamescope sessions so Plasma remains user-owned.
if dmi_matches ga402; then
	for session in steam ogui-steam; do
		file_write "/etc/gamescope-session-plus/sessions.d/$session" <<'EOF'
ADAPTIVE_SYNC=1
PANEL_TYPE=internal
CUSTOM_REFRESH_RATES=60,120
STEAM_DISPLAY_REFRESH_LIMITS=60,120
VULKAN_ADAPTER=1002:73ef
EOF
	done
fi

file_write "$HOME/.config/rog/rog-control-center.cfg" <<'EOF'
(
    run_in_background: true,
    startup_in_background: true,
    enable_tray_icon: true,
    ac_command: "",
    bat_command: "",
    dark_mode: true,
    start_fullscreen: false,
    fullscreen_width: 1920,
    fullscreen_height: 1080,
    notifications: (
        enabled: false,
        receive_notify_gfx: true,
        receive_notify_gfx_status: true,
    ),
)
EOF
install -d -m 0755 "$HOME/.config/autostart"
ln -sfn /usr/share/applications/rog-control-center.desktop \
	"$HOME/.config/autostart/rog-control-center.desktop"
