#!/usr/bin/env bash
## Deno JavaScript/TypeScript runtime
## https://deno.com
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

packages=(
	arch:deno
	fedora:terra/deno
)

module_apply() {
	# Keep the Deno cache out of $HOME root, in the XDG cache location.
	install -d -m 0755 "$HOME/.cache/deno"
	# shellcheck disable=SC2016
	shell_set_env deno DENO_DIR '$HOME/.cache/deno'
}

module_entrypoint "$@"
