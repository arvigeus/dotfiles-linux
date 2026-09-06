#!/usr/bin/env bash
## Chrono Divide — browser remake of Red Alert 2
## https://github.com/chronodivide
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/webapp.sh"

packages=(chromium)

module_apply() {
	webapp_install \
		'Chrono Divide' \
		https://game.chronodivide.com/ \
		red-alert-2 \
		'Game;StrategyGame;'
}

module_entrypoint "$@"
