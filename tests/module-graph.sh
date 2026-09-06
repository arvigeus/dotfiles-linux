#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/root/run"

TARGET_ROOT="$TEST_ROOT/root"
PROJECT_ID=system
HOSTNAME=zephyrus
DISTRO=arch
PACKAGE_MANAGER=pacman
USERNAME=tester
USER_UID=1000
USER_GID=1000
HOME_DELETE_MODE=unchanged
PRESERVE_REQUESTS=/run/system-preserve-requests
PACKAGE_PLAN=/run/system-package-plan.tsv
: >"$TARGET_ROOT$PRESERVE_REQUESTS"
: >"$TARGET_ROOT$PACKAGE_PLAN"

# shellcheck source=installer/modules.sh
source "$PROJECT_ROOT/installer/modules.sh"

# Execute only the plan phase directly; production wraps the same command in
# the target mount namespace.
_run_module() {
	local phase=$1 module=$2 module_id=$3 plan_file=$4
	env \
		HOME="$TEST_ROOT/home" \
		XDG_CONFIG_HOME="$TEST_ROOT/home/.config" \
		XDG_DATA_HOME="$TEST_ROOT/home/.local/share" \
		XDG_STATE_HOME="$TEST_ROOT/home/.local/state" \
		XDG_CACHE_HOME="$TEST_ROOT/cache" \
		SETUP_ROOT="$PROJECT_ROOT" \
		MODULE_DIR="$(dirname -- "$module")" \
		MODULE_ID="$module_id" \
		MODULE_PHASE="$phase" \
		MODULE_PLAN_FILE="$TARGET_ROOT$plan_file" \
		USERNAME="$USERNAME" USER_UID="$USER_UID" USER_GID="$USER_GID" \
		DISTRO="$DISTRO" PACKAGE_MANAGER="$PACKAGE_MANAGER" PROJECT_ID="$PROJECT_ID" \
		PRESERVE_REQUESTS_FILE="$TARGET_ROOT$PRESERVE_REQUESTS" \
		HOME_DELETE_MODE="$HOME_DELETE_MODE" \
		bash "$module"
}

die() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

log() {
	:
}

_load_host_modules
for selector in "${HOST_MODULES[@]}"; do
	_resolve_module "$selector"
done
((${#SELECTED_MODULE_IDS[@]} > 50))
rg -q $'gaming/steam\t.*\tarch:multilib/steam$' "$TARGET_ROOT$PACKAGE_PLAN"
rg -q $'dev/editors/vscode\t.*\tfedora:vscode/code$' "$TARGET_ROOT$PACKAGE_PLAN"
rg -q $'system/security/ssh/client\t.*\tarch:openssh$' "$TARGET_ROOT$PACKAGE_PLAN"
if rg -q 'openssh-server' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'soft-disabled SSH server contributed packages to the plan'
fi
if rg -q 'cloudflare-warp-bin' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'soft-disabled Cloudflare module contributed packages to the plan'
fi

validation_plan="$TEST_ROOT/validation-plan.tsv"
sed "s#\t/run/$PROJECT_ID/#\t$PROJECT_ROOT/#" \
	"$TARGET_ROOT$PACKAGE_PLAN" >"$validation_plan"
SETUP_ROOT=$PROJECT_ROOT
# shellcheck source=lib/package.sh
source "$PROJECT_ROOT/lib/package.sh"
_pkg_validate_plan "$validation_plan"
unset SETUP_ROOT
preflight_modules
DISTRO=fedora PACKAGE_MANAGER=dnf preflight_modules

MODULE_STATES=()
MODULE_FILE_OWNERS=()
SELECTED_MODULE_IDS=()
SELECTED_MODULE_FILES=()
SELECTED_MODULE_DIRS=()
: >"$TARGET_ROOT$PACKAGE_PLAN"
_resolve_module gaming/steam
_resolve_module gaming/steam
[[ ${#SELECTED_MODULE_IDS[@]} == 1 ]]
[[ ${SELECTED_MODULE_IDS[0]} == gaming/steam ]]
rg -q 'arch:multilib/steam$' "$TARGET_ROOT$PACKAGE_PLAN"
if rg -q 'lutris' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'selecting gaming/steam also selected Lutris'
fi

mkdir -p "$TEST_ROOT/files-a/files/etc" "$TEST_ROOT/files-b/files/etc"
printf 'a\n' >"$TEST_ROOT/files-a/files/etc/conflict.conf"
printf 'b\n' >"$TEST_ROOT/files-b/files/etc/conflict.conf"
MODULE_FILE_OWNERS=()
_register_module_files files-a "$TEST_ROOT/files-a"
if _register_module_files files-b "$TEST_ROOT/files-b" 2>/dev/null; then
	die 'conflicting module file overlays were accepted'
fi

mkdir -p "$TEST_ROOT/files-link/files/etc"
ln -s /etc/passwd "$TEST_ROOT/files-link/files/etc/link"
if _register_module_files files-link "$TEST_ROOT/files-link" 2>/dev/null; then
	die 'a symlink in a module file overlay was accepted'
fi

printf 'module graph: ok\n'
