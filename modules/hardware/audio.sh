#!/usr/bin/env bash
## https://pipewire.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	pipewire
	wireplumber
	pipewire-alsa
	arch:pipewire-pulse
	fedora:pipewire-pulseaudio
)

module_entrypoint "$@"
