#!/usr/bin/env bash
## AI Image Upscaler
## https://www.gimp.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

module_healthcheck() {
	repo_health https://github.com/upscayl/upscayl -m 12
}

packages=(
	flathub/org.upscayl.Upscayl
)
module_apply() {
	flatpak_alias upscayl flathub/org.upscayl.Upscayl
}

module_entrypoint "$@"
