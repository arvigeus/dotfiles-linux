#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

recipe="$TEST_ROOT/recipes/arch/test"
mkdir -p "$recipe"
printf 'large package payload\n' >"$TEST_ROOT/source.bin"
export TEST_RECIPE_SOURCE="$TEST_ROOT/source.bin"

cat >"$recipe/update.sh" <<'UPDATE'
resolved_hash=$(hash_url "file://$TEST_RECIPE_SOURCE" cached.bin)
printf '%s\n' "$resolved_hash" >"$RECIPE_DIR/resolved.sha256"
UPDATE

bash "$PROJECT_ROOT/packages/update.sh" "$TEST_ROOT/recipes" arch
cmp "$TEST_ROOT/source.bin" "$recipe/cached.bin"
expected=$(sha256sum "$TEST_ROOT/source.bin" | awk '{print $1}')
[[ $(<"$recipe/resolved.sha256") == "$expected" ]]

printf 'package recipe helpers: ok\n'
