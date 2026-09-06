#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export SETUP_ROOT=$PROJECT_ROOT
export DISTRO=arch
export PACKAGE_MANAGER=pacman
export PROJECT_ID=system
export MODULE_ID=test/leaf
export MODULE_DIR="$TEST_ROOT/module"
export MODULE_PLAN_FILE="$TEST_ROOT/plan.tsv"
mkdir -p "$MODULE_DIR/files/etc/test-module" "$TEST_ROOT/root"
printf 'owned by module\n' >"$MODULE_DIR/files/etc/test-module/value"

# shellcheck source=lib/module.sh
source "$PROJECT_ROOT/lib/module.sh"

packages=(arch:test/example fedora:ignored)
# shellcheck disable=SC2034 # consumed through a nameref by module_entrypoint
sources=(arch:test)
# shellcheck disable=SC2034 # consumed through a nameref by module_entrypoint
requires=(base/utils)

MODULE_PHASE=plan
module_entrypoint
expected=$'leaf\ttest/leaf\nrequire\tbase/utils\nsource\tarch:test\npackage\tarch:test/example\npackage\tfedora:ignored'
[[ $(<"$MODULE_PLAN_FILE") == "$expected" ]]

module_apply() {
	printf 'applied\n' >"$TEST_ROOT/applied"
}
module_healthcheck() {
	printf 'healthy\n' >"$TEST_ROOT/healthy"
}
MODULE_PHASE=apply
MODULE_ROOT="$TEST_ROOT/root"
module_entrypoint
[[ -f $TEST_ROOT/root/etc/test-module/value ]]
[[ $(<"$TEST_ROOT/applied") == applied ]]
[[ ! -e $TEST_ROOT/healthy ]]

MODULE_PHASE=healthcheck
module_entrypoint
[[ $(<"$TEST_ROOT/healthy") == healthy ]]

printf 'module contract: ok\n'
