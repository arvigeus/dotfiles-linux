#!/usr/bin/env bash
## Node.js and JavaScript package managers
## https://nodejs.org
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:extra/nodejs
	arch:extra/npm
	fedora:nodejs
	fedora:npm
	arch:bun # https://bun.com
	fedora:terra/bun-bin
	pnpm # https://pnpm.io
	# yarn # https://yarnpkg.com/
)

module_entrypoint "$@"
