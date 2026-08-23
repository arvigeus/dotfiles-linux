#!/usr/bin/env bash
## Shell scripting tooling — linter and formatter for POSIX shell variants
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	shellcheck # https://www.shellcheck.net/
	shfmt # https://github.com/mvdan/sh
)

pkg_install "${packages[@]}"
