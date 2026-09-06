#!/usr/bin/env bash
##  Discover and run local AI apps by serving optimized LLMs
## https://lemonade-server.ai/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	lemonade-server
)
module_entrypoint "$@"
