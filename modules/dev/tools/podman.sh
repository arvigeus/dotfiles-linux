#!/usr/bin/env bash
## Podman — daemonless container engine + Docker compat shims
## https://wiki.archlinux.org/title/Podman
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	podman
	podman-docker
	docker-compose
	podman-compose
	flathub/com.github.marhkb.Pods
)

module_apply() {
	flatpak_alias pods com.github.marhkb.Pods

	# The user socket is intentionally not enabled here; there is no user manager
	# in the candidate root. Users may enable podman.socket after login.
}

module_entrypoint "$@"
