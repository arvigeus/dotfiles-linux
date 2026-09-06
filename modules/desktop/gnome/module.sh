#!/usr/bin/env bash
## Gnome (TODO)
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

module_check() {
	return 1
}

packages=(
	flathub/page.tesk.Refine
	flathub/io.otsaloma.gaupol
	flathub/com.github.neithern.g4music
	flathub/com.rafaelmardojai.Blanket
	flathub/com.github.johnfactotum.Foliate
	flathub/de.swsnr.pictureoftheday
)

module_apply() {
	flatpak_alias refine page.tesk.Refine
	flatpak_alias gaupol io.otsaloma.gaupol
	flatpak_alias g4music com.github.neithern.g4music
	flatpak_alias blanket com.rafaelmardojai.Blanket
	flatpak_alias foliate com.github.johnfactotum.Foliate
	flatpak_alias pictureoftheday de.swsnr.pictureoftheday
}

module_entrypoint "$@"
