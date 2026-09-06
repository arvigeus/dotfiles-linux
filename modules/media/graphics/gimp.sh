#!/usr/bin/env bash
## GIMP and system-preinstalled Flatpak plug-ins
## https://www.gimp.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

module_healthcheck() {
	repo_health https://github.com/bootchk/resynthesizer -m 12
	repo_health https://github.com/rpeyron/plugin-gimp-fourier -m 12
}

packages=(
	flathub/org.gimp.GIMP
	flathub/runtime/org.gimp.GIMP.Plugin.Resynthesizer/x86_64/3
	flathub/runtime/org.gimp.GIMP.Plugin.Fourier/x86_64/3
	flathub/runtime/org.gimp.GIMP.Plugin.GMic/x86_64/3
)
module_apply() {
	flatpak_alias gimp org.gimp.GIMP
}

module_entrypoint "$@"
