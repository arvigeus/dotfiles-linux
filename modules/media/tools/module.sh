#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
members=(ffmpeg image mkvtoolnix pdf subtitles)
module_entrypoint "$@"
