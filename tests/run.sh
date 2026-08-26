#!/usr/bin/env bash
set -Eeuo pipefail

TEST_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bash "$TEST_ROOT/package.sh"
bash "$TEST_ROOT/native-manager.sh"
bash "$TEST_ROOT/files.sh"
bash "$TEST_ROOT/gaming.sh"
bash "$TEST_ROOT/static.sh"
