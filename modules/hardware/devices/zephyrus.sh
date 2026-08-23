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
	# Userspace support only. The clean-root backend owns the kernel and UKI;
	# silently replacing it with linux-g14 here would produce a mismatched UKI.
	pkg_install \
		arch:g14/asusctl \
		arch:g14/rog-control-center \
		power-profiles-daemon \
		switcheroo-control
	;;
fedora)
	if pkg_is_installed tuned-ppd; then
		dnf -y swap --allowerasing tuned-ppd power-profiles-daemon
	else
		pkg_install power-profiles-daemon
	fi
	pkg_install fedora:terra/asusctl fedora:terra/asusctl-rog-gui switcheroo-control
	systemctl enable asusd.service
	;;
esac

systemctl enable power-profiles-daemon.service switcheroo-control.service

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
