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

# Stable release validation and resolving an annotated tag through the commits
# API must work without falling back to a development snapshot.
cat >"$recipe/update.sh" <<'UPDATE'
github_api() {
	case $1 in
	*/releases/latest) printf '%s\n' "$TEST_RELEASE_JSON" ;;
	*/commits/v2.3.4)
		printf '%s\n' '{"sha":"0123456789012345678901234567890123456789","commit":{"author":{"date":"2026-10-01T00:00:00Z"}}}'
		;;
	*) return 1 ;;
	esac
}
release_commit_resolve example/project
printf '%s %s %s\n' "$RELEASE_VERSION" "$HEAD_COMMIT" "$HEAD_DATE" >"$RECIPE_DIR/resolved-release"
UPDATE
export TEST_RELEASE_JSON='{"tag_name":"v2.3.4","draft":false,"prerelease":false}'
bash "$PROJECT_ROOT/packages/update.sh" "$TEST_ROOT/recipes" arch
[[ $(<"$recipe/resolved-release") == '2.3.4 0123456789012345678901234567890123456789 20261001' ]]
for rejected in \
	'{"tag_name":"v2.3.4","draft":true,"prerelease":false}' \
	'{"tag_name":"v2.3.4","draft":false,"prerelease":true}' \
	'{"tag_name":"v2.3.4"}'; do
	if TEST_RELEASE_JSON="$rejected" bash "$PROJECT_ROOT/packages/update.sh" "$TEST_ROOT/recipes" arch \
		>"$TEST_ROOT/rejected.log" 2>&1; then
		printf 'Updater accepted an unverified stable release\n' >&2
		exit 1
	fi
	rg -q 'did not return a stable release' "$TEST_ROOT/rejected.log"
done

# Exercise the shared install/rebuild orchestration, with only mounts/chroot and
# package installation stubbed. Recipes must refresh before package/application
# phases on both distributions, and failure must stop those phases.
(
	REPOSITORY_ROOT=$PROJECT_ROOT
	source "$REPOSITORY_ROOT/installer/modules.sh"
	PROJECT_ROOT="$TEST_ROOT/project"
	PROJECT_ID=system HOSTNAME=fixture HOST_PROFILE=fixture
	mkdir -p "$PROJECT_ROOT/packages" "$PROJECT_ROOT/modules/fixture"
	cp "$REPOSITORY_ROOT/packages/update.sh" "$PROJECT_ROOT/packages/"
	for distro in arch fedora; do
		fixture_recipe="$PROJECT_ROOT/modules/fixture/packages/$distro/example"
		mkdir -p "$fixture_recipe"
		printf 'version=old\n' >"$fixture_recipe/PKGBUILD"
		cat >"$fixture_recipe/update.sh" <<'UPDATE'
replace_line "$RECIPE_DIR/PKGBUILD" '^version=' 'version=latest-stable'
UPDATE
	done
	log() { :; }
	provision_checkpoint() { :; }
	mount() { :; }
	tracked_bind_mount() {
		mkdir -p "$2"
		cp -a "$1/." "$2/"
	}
	target_chroot() {
		local argument translated=()
		for argument in "$@"; do
			[[ $argument != /run/* ]] || argument="$TARGET_ROOT$argument"
			translated+=("$argument")
		done
		"${translated[@]}"
	}
	_load_host_modules() { HOST_MODULES=(fixture); }
	_resolve_module() {
		SELECTED_MODULE_IDS+=(fixture)
		SELECTED_MODULE_FILES+=("$PROJECT_ROOT/modules/fixture/module.sh")
		SELECTED_MODULE_DIRS+=("$PROJECT_ROOT/modules/fixture")
	}
	_apply_package_plan() {
		local updated="$TARGET_ROOT/run/system-package-recipes/fixture/$DISTRO/example/PKGBUILD"
		[[ $(<"$updated") == 'version=latest-stable' ]]
		[[ $(<"$PROJECT_ROOT/modules/fixture/packages/$DISTRO/example/PKGBUILD") == 'version=old' ]]
		[[ -s $TARGET_ROOT/var/log/system/package-recipes/fixture/$DISTRO/example/PKGBUILD ]]
		printf 'packages\n' >"$TARGET_ROOT/phases"
	}
	_run_module() { printf '%s\n' "$1" >>"$TARGET_ROOT/phases"; }
	for DISTRO in arch fedora; do
		TARGET_ROOT="$TEST_ROOT/target-$DISTRO"
		run_modules
		[[ $(<"$TARGET_ROOT/phases") == $'packages\napply' ]]
	done
	printf 'return 1\n' >"$PROJECT_ROOT/modules/fixture/packages/arch/example/update.sh"
	driver="$TEST_ROOT/provision-functions.sh"
	declare -f run_modules _prepare_module_packages _module_checkpoint log provision_checkpoint \
		mount tracked_bind_mount target_chroot _load_host_modules _resolve_module \
		_apply_package_plan _run_module >"$driver"
	export PROJECT_ROOT PROJECT_ID HOSTNAME HOST_PROFILE
	# A separate Bash preserves production errexit semantics; calling a function
	# inside an `if` in this shell would disable errexit throughout its body.
	if env DISTRO=arch TARGET_ROOT="$TEST_ROOT/failed-target" \
		bash -euo pipefail -c 'source "$1"; run_modules' bash "$driver" \
		>"$TEST_ROOT/failed.log" 2>&1; then
		printf 'Recipe failure did not stop provisioning\n' >&2
		exit 1
	fi
	[[ ! -e $TEST_ROOT/failed-target/phases ]]
)
printf 'automatic recipe refresh before install/rebuild: ok\n'
