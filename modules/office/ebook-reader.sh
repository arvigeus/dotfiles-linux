#!/usr/bin/env bash
## E-book reader with EPUB, Kindle, FB2, comic-book, and PDF support
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(flathub/com.github.johnfactotum.Foliate)

module_apply() {
	flatpak_alias foliate com.github.johnfactotum.Foliate
}

module_entrypoint "$@"
