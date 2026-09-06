#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(kodi mpv syncplay vlc youtube)
module_entrypoint "$@"
