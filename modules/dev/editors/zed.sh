#!/usr/bin/env bash
## Zed — high-performance multiplayer code editor
## https://zed.dev/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
  arch:zed
  fedora:terra/zed
)
pkg_install "${packages[@]}"

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
    "default_model": {
      "provider": "openrouter",
      "model": "google/gemma-4-31b-it:free"
    },
    "play_sound_when_agent_done": true
  },
  "ui_font_size": 16,
  "buffer_font_size": 14,
  "theme": {
    "mode": "system",
    "light": "One Light",
    "dark": "One Dark Pro"
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
    "harper": true,
    "one-dark-pro": true
  },
  "file_types": {
    "Dockerfile": ["Dockerfile.*", "Containerfile.*"]
  }
}
EOF

# https://zed.dev/docs/key-bindings
file_write "$HOME/.config/zed/keymap.json" <<'EOF'
[
  {
    "context": "Workspace",
    "bindings": {
      "ctrl-`": "terminal_panel::ToggleFocus"
    }
  },
  {
    "context": "Terminal",
    "bindings": {
      "ctrl-`": "workspace::ToggleBottomDock",
      "cmd-n": "workspace::NewTerminal"
    }
  }
]
EOF
