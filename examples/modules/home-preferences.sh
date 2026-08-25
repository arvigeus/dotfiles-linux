#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

# During a build HOME=/etc/skel. The .json suffix automatically selects the
# JSON merger; no policy declaration is needed for ordinary files.
install -Dm644 \
	"$MODULE_DIR/preferences.json" \
	"$HOME/.config/system/preferences.json"
