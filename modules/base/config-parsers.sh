#!/usr/bin/env bash
## Tools for managing config files
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
    jq
    crudini    # INI file editor
    xmlstarlet # XML processor/editor
    arch:go-yq # YAML processor
    fedora:yq
    jq # JSON processor
)

pkg_install "${packages[@]}"
