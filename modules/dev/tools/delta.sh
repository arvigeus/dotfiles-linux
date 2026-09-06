#!/usr/bin/env bash
## delta — syntax-highlighting pager for git/diff output
## https://github.com/dandavison/delta
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

packages=(
	git-delta
	diffutils
)

module_healthcheck() {
	repo_health https://github.com/dandavison/delta -m 12
}

module_entrypoint "$@"
