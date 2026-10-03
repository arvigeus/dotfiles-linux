#!/usr/bin/env bash
## Python development with uv, Ruff and ty; pip for compatibility
## https://www.python.org/ https://docs.astral.sh/uv/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

packages=(
	arch:python
	fedora:python3
	arch:python-pip
	fedora:python3-pip
	uv
	ruff
	ty
)

module_apply() {
	# Keep the REPL history out of $HOME root, in the XDG state location
	# (honored by Python 3.13+; ignored by older versions).
	# Pin the pip cache to its XDG-default location so an unset XDG_*
	# var cannot push it elsewhere. Values stay unexpanded until login.
	install -d -m 0755 "$HOME/.local/state/python" "$HOME/.cache/pip"
	# shellcheck disable=SC2016
	shell_set_env python PYTHONHISTORY '$HOME/.local/state/python/history'
	# shellcheck disable=SC2016
	shell_set_env python PIP_CACHE_DIR '$HOME/.cache/pip'
}

module_healthcheck() {
	local command
	for command in python3 uv ruff ty; do
		command -v "$command" >/dev/null || {
			printf 'Python development command missing: %s\n' "$command" >&2
			return 1
		}
	done
	python3 -m pip --version >/dev/null
}

module_entrypoint "$@"
