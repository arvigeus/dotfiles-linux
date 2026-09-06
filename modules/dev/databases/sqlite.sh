#!/usr/bin/env bash
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	# https://www.sqlite.org/
	sqlite
	sqlitebrowser
)

module_entrypoint "$@"

## Tips:
## - Solve Sudoku with a recursive CTE:
##   https://www.sqlite.org/lang_with.html#outlandish_recursive_query_examples
