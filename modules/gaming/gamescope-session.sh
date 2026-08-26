#!/usr/bin/env bash
## Dedicated Gamescope/Steam login session
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

file_write -m 0755 /usr/local/bin/system-gaming-session \
	<"$MODULE_DIR/system-gaming-session"

file_write /usr/share/wayland-sessions/system-gaming.desktop \
	<"$MODULE_DIR/system-gaming.desktop"
