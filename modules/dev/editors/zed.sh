#!/usr/bin/env bash
## Zed — high-performance multiplayer code editor
## https://zed.dev/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:zed
	fedora:terra/zed
)
module_apply() {

	## Related:
	## - https://zed-themes.com
	## - https://zed.dev/extensions
	## - https://zed.dev/theme-builder

	# https://zed.dev/docs/reference/all-settings
	file_write "$HOME/.config/zed/settings.json" <<'EOF'
{
  "git": {
    "inline_blame": {
      "enabled": false
    }
  },
  "diagnostics": {
    "inline": {
      "enabled": true
    }
  },
  "agent": {
    "notify_when_agent_waiting": true,
    "play_sound_when_agent_done": true
  },
  "ui_font_size": 16,
  "buffer_font_size": 14,
  "theme": {
    "mode": "system"
  },
  "auto_install_extensions": {
    "html": true,
    "basher": true,
    "dockerfile": true,
    "biome": true,
    "stylelint": true,
    "deno": true,
    "just": true,
    "crates-lsp": true,
    "csharp": true,
    "graphql": true,
    "toml": true,
    "comment": true,
    "env": true,
    "git-firefly": true,
    "harper": true
  },
  "file_types": {
    "Dockerfile": ["Dockerfile.*", "Containerfile.*"]
  }
}
EOF
}

module_entrypoint "$@"
