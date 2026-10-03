#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
case ${DESKTOP:?DESKTOP must be passed by the installer} in
plasma | hyprland) members=(electron fonts "$DESKTOP") ;;
*)
	printf 'Unknown desktop: %s\n' "$DESKTOP" >&2
	exit 1
	;;
esac
module_entrypoint "$@"
