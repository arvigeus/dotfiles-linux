#!/usr/bin/env bash
## just — command runner and Justfile language tooling
## https://just.systems/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	just
	arch:just-lsp
	fedora:cargo/just-lsp
)

module_entrypoint "$@"
