#!/usr/bin/env bash
## Vietnamese Telex, configured for explicit startup only.
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"
module_check() { [[ ${DESKTOP:-} == plasma || ${DESKTOP:-} == hyprland ]]; }
requires=(hardware/keyboard/input-method/bg)
packages=(fcitx5 fcitx5-qt fcitx5-gtk fcitx5-configtool fcitx5-unikey)
module_apply() {
	file_write /usr/share/applications/system-vietnamese.desktop <<'ENTRY'
[Desktop Entry]
Type=Application
Name=Vietnamese Telex
Comment=Enable Vietnamese input for this session
Exec=system-input-method select vi --notify
Icon=input-keyboard
Categories=Settings;Utility;
Actions=Stop;

[Desktop Action Stop]
Name=Stop Vietnamese input
Exec=system-input-method select bg --notify
ENTRY
	file_write /usr/share/applications/system-vietnamese-stop.desktop <<'ENTRY'
[Desktop Entry]
Type=Application
Name=Stop Vietnamese input
Comment=Return to English and Bulgarian phonetic
Exec=system-input-method select bg --notify
Icon=input-keyboard
Categories=Settings;Utility;
ENTRY
	file_write /usr/share/applications/system-fcitx5-kwin.desktop <<'ENTRY'
[Desktop Entry]
Type=Application
Name=Vietnamese Telex (on demand)
Exec=/usr/local/bin/system-input-method kwin-launch
NoDisplay=true
X-KDE-Wayland-VirtualKeyboard=true
ENTRY
	file_write /usr/lib/systemd/user/system-vietnamese.service <<'UNIT'
[Unit]
Description=Vietnamese Telex (explicit start only)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=dbus
BusName=org.fcitx.Fcitx5
ExecStart=/usr/bin/fcitx5
TimeoutStartSec=10
UNIT
	# Block package autostart and D-Bus activation by toolkit clients. Neither
	# installing the module nor opening a Qt app should start an input daemon.
	file_write "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" <<'ENTRY'
[Desktop Entry]
Type=Application
Name=Fcitx 5
Hidden=true
ENTRY
	file_write "$HOME/.local/share/dbus-1/services/org.fcitx.Fcitx5.service" <<'ENTRY'
[D-BUS Service]
Name=org.fcitx.Fcitx5
Exec=/usr/bin/false
ENTRY
	home_strategy .config/autostart/org.fcitx.Fcitx5.desktop replace never
	home_strategy .local/share/dbus-1/services/org.fcitx.Fcitx5.service replace never

	system_set_env fcitx XMODIFIERS @im=fcitx
	if [[ $DESKTOP == hyprland ]]; then
		system_set_env fcitx QT_IM_MODULE fcitx
	else
		kwriteconfig6 --file "$HOME/.config/kwinrc" --group Wayland --key InputMethod /usr/share/applications/system-fcitx5-kwin.desktop
		home_strategy .config/kwinrc ini unchanged
	fi
	system-input-method configure "$DESKTOP"
	for config in profile config conf/unikey.conf conf/wayland.conf; do
		home_strategy ".config/fcitx5/$config" replace unchanged
	done
}
module_entrypoint "$@"
