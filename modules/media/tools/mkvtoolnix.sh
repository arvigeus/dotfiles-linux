#!/usr/bin/env bash
## MKVToolNix — Matroska GUI and CLI tools
## https://mkvtoolnix.download/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/org.bunkus.mkvtoolnix-gui
)
module_apply() {
	flatpak_alias mkvtoolnix-gui org.bunkus.mkvtoolnix-gui
	flatpak_alias mkvmerge org.bunkus.mkvtoolnix-gui mkvmerge
	flatpak_alias mkvextract org.bunkus.mkvtoolnix-gui mkvextract
	flatpak_alias mkvinfo org.bunkus.mkvtoolnix-gui mkvinfo
	flatpak_alias mkvpropedit org.bunkus.mkvtoolnix-gui mkvpropedit
}

module_entrypoint "$@"
