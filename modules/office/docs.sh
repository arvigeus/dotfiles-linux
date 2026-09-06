#!/usr/bin/env bash
## LibreOffice
## https://www.libreoffice.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	# https://www.libreoffice.org
	flathub/org.libreoffice.LibreOffice
	# Alternatives:
	# - EuroOffice 🇪🇺
	# - OnlyOffice 🇷🇺
	# - WPS Office 🇨🇳
)

module_apply() {
	flatpak_alias libreoffice org.libreoffice.LibreOffice
}

module_entrypoint "$@"
