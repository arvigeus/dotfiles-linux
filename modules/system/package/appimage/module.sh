#!/usr/bin/env bash
## AppImage support through AppManager
## https://aur.archlinux.org/packages/appmanager
## https://github.com/kem-a/AppManager
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

module_healthcheck() {
	repo_health https://github.com/kem-a/AppManager -m 12
}

packages=(
	arch:aur/appmanager
	fedora:rpmspec/appmanager
)

module_entrypoint "$@"

# The Fedora recipe omits unavailable DwarFS and zsync helpers. It still
# manages ordinary SquashFS AppImages without FUSE 2.
