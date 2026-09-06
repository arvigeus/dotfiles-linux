#!/usr/bin/env bash
## micro - a modern and intuitive terminal-based text editor
## https://micro-editor.github.io/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	micro
)

module_entrypoint "$@"

## Keybindings:
# `Ctrl + Q`: Quit
# `Ctrl + C`: Copy
# `Ctrl + V`: Paste
# `Ctrl + Z`: Undo
