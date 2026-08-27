#!/usr/bin/env bash
## AppImage support through AppManager
## https://aur.archlinux.org/packages/appmanager
## https://github.com/kem-a/AppManager
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:aur/appmanager
	fedora:rpmspec/appmanager
)
pkg_install "${packages[@]}"

# The Fedora recipe omits unavailable DwarFS and zsync helpers. It still
# manages ordinary SquashFS AppImages without FUSE 2.
