#!/usr/bin/env bash
set -Eeuo pipefail

TEST_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bash "$TEST_ROOT/package.sh"
bash "$TEST_ROOT/package-recipes.sh"
bash "$TEST_ROOT/git-pkgbuild.sh"
bash "$TEST_ROOT/module.sh"
bash "$TEST_ROOT/module-graph.sh"
bash "$TEST_ROOT/config.sh"
bash "$TEST_ROOT/desktop-home.sh"
python3 "$TEST_ROOT/input-method.py"
bash "$TEST_ROOT/slots.sh"
bash "$TEST_ROOT/firefox.sh"
bash "$TEST_ROOT/private-hydration.sh"
bash "$TEST_ROOT/native-manager.sh"
bash "$TEST_ROOT/files.sh"
bash "$TEST_ROOT/efi.sh"
bash "$TEST_ROOT/flatpak.sh"
bash "$TEST_ROOT/gaming.sh"
bash "$TEST_ROOT/static.sh"
bash "$TEST_ROOT/system-update.sh"
