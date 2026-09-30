#!/usr/bin/env bash
## mise — per-project runtime version manager
## https://mise.jdx.dev/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

packages=(
	arch:mise
	fedora:mise/mise
)
module_apply() {
	# Pin mise state to XDG locations so it never lands in $HOME root.
	install -d -m 0755 "$HOME/.local/share/mise" "$HOME/.cache/mise" "$HOME/.config/mise"
	# shellcheck disable=SC2016
	shell_set_env mise MISE_DATA_DIR '$HOME/.local/share/mise'
	# shellcheck disable=SC2016
	shell_set_env mise MISE_CACHE_DIR '$HOME/.cache/mise'
	# shellcheck disable=SC2016
	shell_set_env mise MISE_CONFIG_DIR '$HOME/.config/mise'

	shell_profile mise <<'EOF'
if command -v mise >/dev/null 2>&1; then
	if [ -n "${BASH_VERSION:-}" ]; then
		eval "$(mise activate bash)"
	elif [ -n "${ZSH_VERSION:-}" ]; then
		eval "$(mise activate zsh)"
	fi
fi
EOF

	file_write /etc/fish/conf.d/mise.fish <<'EOF'
if command -q mise
	mise activate fish | source
end
EOF
}

module_entrypoint "$@"
