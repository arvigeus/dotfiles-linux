#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$PROJECT_ROOT/installer/common.sh"
source "$PROJECT_ROOT/installer/disk.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
ROOT_A=@root-a ROOT_B=@root-b TOP_LEVEL="$TEST_ROOT/top" MAPPER_DEVICE=/dev/fake
active_slot() { printf '@root-b\n'; }
tracked_mount() { printf 'mount %s\n' "$*" >>"$TEST_ROOT/calls"; }
cleanup_mounts() { :; }
log() { :; }
btrfs() {
	if [[ $* == 'subvolume delete --help' ]]; then
		printf '%s\n' '--recursive'
		return
	fi
	printf '%s\n' "$*" >>"$TEST_ROOT/calls"
	if [[ $* == 'subvolume delete '* && ${TEST_DELETE_FAIL:-false} == true ]]; then return 1; fi
}
prepare_empty_slot @root-a
rg -q "^subvolume delete --recursive --commit-after $TOP_LEVEL/@root-a$" "$TEST_ROOT/calls"
rg -q 'subvolid=5' "$TEST_ROOT/calls"
for forbidden in @root-b @home ../outside; do
	: >"$TEST_ROOT/calls"
	if (prepare_empty_slot "$forbidden") 2>/dev/null; then exit 1; fi
	[[ ! -s $TEST_ROOT/calls ]]
done
ln -s "$TOP_LEVEL/@root-b" "$TOP_LEVEL/@root-a"
if (prepare_empty_slot @root-a) 2>/dev/null; then exit 1; fi
if rg -q '^subvolume delete --recursive' "$TEST_ROOT/calls"; then exit 1; fi
rm "$TOP_LEVEL/@root-a"
: >"$TEST_ROOT/calls"
if TEST_DELETE_FAIL=true prepare_empty_slot @root-a; then exit 1; fi
if rg -q '^subvolume create' "$TEST_ROOT/calls"; then exit 1; fi
printf 'inactive slot deletion boundaries: ok\n'
