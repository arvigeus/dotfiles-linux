#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	mangohud
	arch:lib32-mangohud
	fedora:mangohud.i686
)

module_apply() {
	# Installing MangoHud does not inject it globally. This compact default is used
	# only when a game or launcher explicitly requests the overlay.
	file_write "$HOME/.config/MangoHud/MangoHud.conf" <<'EOF'
position=top-left
fps
frametime
gpu_stats
gpu_temp
gpu_power
cpu_stats
cpu_temp
ram
vram
engine_version
wine
toggle_hud=Shift_R+F12
EOF
}

module_entrypoint "$@"
