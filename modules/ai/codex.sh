#!/usr/bin/env bash
## OpenAI Codex CLI and official ChatGPT desktop application
## https://developers.openai.com/codex/cli
## https://developers.openai.com/codex/linux/linux-app
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	# Arch repackages OpenAI's official Linux desktop payload from the AUR.
	arch:aur/chatgpt-desktop
	arch:aur/openai-codex-bin

	# OpenAI officially supports the desktop RPM on Fedora 43/44.
	fedora:openai/chatgpt
	fedora:npm/@openai/codex
)
module_entrypoint "$@"
