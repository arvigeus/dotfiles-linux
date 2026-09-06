#!/usr/bin/env bash
## System fonts
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	# Nerd Fonts symbols and Adwaita UI fonts use different package names.
	arch:ttf-nerd-fonts-symbols-mono
	fedora:terra/nerdfontssymbolsonly-nerd-fonts
	arch:adwaita-fonts
	fedora:adwaita-fonts-all
)

module_entrypoint "$@"
