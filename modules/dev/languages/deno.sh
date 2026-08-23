#!/usr/bin/env bash
## Deno JavaScript/TypeScript runtime
## https://deno.com
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	deno
)

pkg_install "${packages[@]}"
