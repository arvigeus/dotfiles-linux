#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/root/run"

TARGET_ROOT="$TEST_ROOT/root"
PROJECT_ID=system
HOSTNAME=graph-test
HOST_PROFILE=zephyrus
DESKTOP=plasma
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
		DESKTOP="$DESKTOP" HOST_PROFILE="$HOST_PROFILE" \
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

# Both profiles resolve real modules, and the package plan explains ownership.
rg -q $'media/video/kodi\t' "$TARGET_ROOT$PACKAGE_PLAN"
rg -q $'desktop/plasma\t' "$TARGET_ROOT$PACKAGE_PLAN"
if rg -q $'desktop/hyprland\t' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'Plasma selected Hyprland'
fi
MODULE_STATES=()
MODULE_FILE_OWNERS=()
SELECTED_MODULE_IDS=()
SELECTED_MODULE_FILES=()
SELECTED_MODULE_DIRS=()
: >"$TARGET_ROOT$PACKAGE_PLAN"
DESKTOP=hyprland
for selector in "${HOST_MODULES[@]}"; do
	_resolve_module "$selector"
done
rg -q $'desktop/hyprland\t.*\tarch:git-pkgbuild/github.com/arvigeus/zephyrus-shell$' "$TARGET_ROOT$PACKAGE_PLAN"
for companion in koko okular ark kate kio-extras kio-fuse udisks2; do
	rg -q "desktop/hyprland.*[[:space:]]$companion$" "$TARGET_ROOT$PACKAGE_PLAN"
done
if rg -q 'hyprutils-git|hyprlang-git|hyprqt6engine-git' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'desktop theme selected git replacements for stable Hyprland libraries'
fi
for tool in uv ruff ty; do
	rg -q "dev/languages/python.*[[:space:]]$tool$" "$TARGET_ROOT$PACKAGE_PLAN"
done
if rg -q 'media/video/kodi|desktop/plasma|plasma-desktop|plasma-login-manager|power-profiles-daemon|tuned|cardwire' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'Hyprland selected an omitted desktop/media or rejected component'
fi
# Shell dependency metadata belongs upstream, not in this leaf's plan.
if rg -q 'desktop/hyprland.*[[:space:]](quickshell|python-dateutil|qmltermwidget|hyprshot|cliphist)$' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'Zephyrus runtime dependency duplicated in dotfiles plan'
fi
preflight_modules
if DISTRO=fedora PACKAGE_MANAGER=dnf preflight_modules >"$TEST_ROOT/fedora-hyprland.log" 2>&1; then
	die 'unsupported Fedora Hyprland runtime passed preflight'
fi
rg -q 'Arch only' "$TEST_ROOT/fedora-hyprland.log"
DESKTOP=plasma

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

# Bulgarian can be selected without installing a Vietnamese input daemon.
MODULE_STATES=()
MODULE_FILE_OWNERS=()
SELECTED_MODULE_IDS=()
SELECTED_MODULE_FILES=()
SELECTED_MODULE_DIRS=()
: >"$TARGET_ROOT$PACKAGE_PLAN"
_resolve_module hardware/keyboard/input-method/bg
rg -q 'hardware/keyboard/input-method/common.*[[:space:]]jq$' "$TARGET_ROOT$PACKAGE_PLAN"
if rg -q 'fcitx|python' "$TARGET_ROOT$PACKAGE_PLAN"; then
	die 'Bulgarian-only input selected a Vietnamese daemon or Python runtime'
fi
_resolve_module hardware/keyboard/input-method/vn
rg -q 'hardware/keyboard/input-method/vn.*[[:space:]]fcitx5-unikey$' "$TARGET_ROOT$PACKAGE_PLAN"

printf 'module graph: ok\n'
