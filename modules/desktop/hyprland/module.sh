#!/usr/bin/env bash
## Zephyrus on Hyprland; system policy belongs here, never in setup-system.sh.
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"

[[ $DISTRO == arch ]] || {
	printf 'Zephyrus Hyprland currently supports Arch only; choose Plasma on Fedora.\n' >&2
	exit 1
}

# UWSM and standard systemd user services own the graphical-session lifecycle.
requires=(hardware/audio hardware/network hardware/bluetooth base/archive base/xdg browsers/firefox)
packages=(
	hyprland quickshell hyprlock hypridle hyprpolkitagent uwsm
	qt6-declarative qt6-wayland qt6-svg qt6-multimedia qmltermwidget
	python python-dateutil python-dbus python-gobject
	xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
	polkit upower libpulse
	# Desktop companions share Qt 6 and the shell palette.
	kitty dolphin koko okular ark kate mpv noto-fonts
	kio-extras kio-fuse ffmpegthumbs kdegraphics-thumbnailers kimageformats qt6-imageformats libheif libavif libjxl
	breeze-icons breeze-gtk udisks2
	# Standalone KDE platform themes let Qt 5 and Qt 6 share generated colors/fonts.
	plasma-integration plasma5-integration
	xdg-utils shared-mime-info desktop-file-utils glib2
	# Helpers have native Quickshell controls, rather than another launcher/bar.
	wl-clipboard cliphist hyprshot satty kooha libnotify
	arch:aur/hyprqt6engine
	brightnessctl ddcutil i2c-tools pciutils
	greetd greetd-tuigreet
	arch:pkgbuild/zephyrus-shell
)

module_apply() {
	local runtime=/usr/share/zephyrus-shell
	[[ -s $runtime/shell.qml && -s $runtime/hyprland/hyprland.lua && -s $runtime/scripts/setup-session.py ]] || {
		printf 'Zephyrus package is incomplete at %s\n' "$runtime" >&2
		return 1
	}
	local session_state
	session_state=$(mktemp -d)
	XDG_STATE_HOME="$session_state" python3 "$runtime/scripts/setup-session.py" install || {
		rm -rf -- "$session_state"
		return 1
	}
	rm -rf -- "$session_state"
	# Track all generated user configuration, including standard service links.
	for config in .config/hypr/hyprland.lua .config/hypr/hyprlock.conf \
		.config/hypr/hypridle.conf .config/xdg-desktop-portal/hyprland-portals.conf \
		.config/systemd/user/zephyrus-shell.service \
		.config/systemd/user/hypridle.service.d/zephyrus.conf \
		.config/systemd/user/hyprpolkitagent.service.d/zephyrus.conf \
		.config/systemd/user/graphical-session.target.wants/zephyrus-shell.service \
		.config/systemd/user/graphical-session.target.wants/hypridle.service \
		.config/systemd/user/graphical-session.target.wants/hyprpolkitagent.service; do
		home_strategy "$config" replace never
	done

	# These are defaults reconciled into persistent home. Existing user edits win.
	for pair in hypr/hyprqt6engine.conf:hyprqt6engine.conf gtk-3.0/settings.ini:settings.ini dolphinrc:dolphinrc kdeglobals:kdeglobals; do
		local destination=${pair%%:*} template=${pair#*:}
		file_write "$HOME/.config/$destination" <"/usr/share/zephyrus-desktop/$template"
		home_strategy ".config/$destination" replace unchanged
	done
	for type in text image; do
		local unit="zephyrus-clipboard@$type.service"
		install -d "$HOME/.config/systemd/user/graphical-session.target.wants"
		ln -sfn /usr/lib/systemd/user/zephyrus-clipboard@.service "$HOME/.config/systemd/user/graphical-session.target.wants/$unit"
		home_strategy ".config/systemd/user/graphical-session.target.wants/$unit" replace never
	done

	printf 'i2c-dev\n' | file_write /etc/modules-load.d/zephyrus-ddc.conf
	getent group i2c >/dev/null || groupadd --system i2c
	usermod --append --groups i2c "$USERNAME"
	getent passwd greeter >/dev/null || useradd --system --no-create-home --shell /usr/bin/nologin greeter
	systemctl enable greetd.service
}

module_healthcheck() {
	local command
	for command in Hyprland start-hyprland uwsm quickshell hyprlock hypridle tuigreet python3 dolphin koko okular ark kwrite kitty mpv hyprshot satty kooha wl-copy wl-paste cliphist xdg-open; do
		command -v "$command" >/dev/null || {
			printf 'Hyprland runtime command missing: %s\n' "$command" >&2
			return 1
		}
	done
	[[ -s /usr/share/zephyrus-shell/REVISION && -s /usr/share/zephyrus-shell/scripts/setup-session.py ]]
	grep -Fq '/usr/share/zephyrus-shell/hyprland/hyprland.lua' "$XDG_CONFIG_HOME/hypr/hyprland.lua"
	systemctl is-enabled --quiet greetd.service
	[[ -f /usr/lib/systemd/user/hyprpolkitagent.service ]]
	python3 -c 'import dateutil, dbus, gi'
	[[ -s /etc/xdg/hyprland-mimeapps.list && -s /usr/share/color-schemes/Zephyrus.colors ]]
	[[ -f /usr/lib/systemd/user/zephyrus-clipboard@.service ]]
}

module_entrypoint "$@"
