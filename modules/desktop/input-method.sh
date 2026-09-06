#!/usr/bin/env bash
## Vietnamese Telex input through Fcitx 5
## Disabled: rename this file to input-method.sh to enable it.
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

module_check() {
	return 1
}

packages=(
	fcitx5
	fcitx5-qt
	fcitx5-gtk
	fcitx5-configtool
	fcitx5-unikey
)
pkg_install "${packages[@]}"

system_set_env fcitx GTK_IM_MODULE fcitx
system_set_env fcitx QT_IM_MODULE fcitx
system_set_env fcitx XMODIFIERS @im=fcitx
system_set_env fcitx SDL_IM_MODULE fcitx

# After enabling, select Fcitx 5 in Plasma's Keyboard > Virtual Keyboard
# settings and configure Unikey/Telex with fcitx5-configtool.
