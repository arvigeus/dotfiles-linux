#!/usr/bin/env bash
## Fresh — terminal text editor
## https://getfresh.dev/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

packages=(
	arch:aur/fresh-editor-bin
	fedora:terra/fresh
)

module_healthcheck() {
	repo_health https://github.com/sinelaw/fresh -m 12
}

module_entrypoint "$@"
