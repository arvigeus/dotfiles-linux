#!/usr/bin/env bash

install_static_files() {
	local files_root="$PROJECT_ROOT/files"
	[[ -d $files_root ]] || return 0

	log "Installing static filesystem overlay"
	cp -R --no-preserve=ownership -- "$files_root/." "$TARGET_ROOT/"
}

_run_module() {
	local module=${1:?module path required}
	local package_recipe_root=${2:?package recipe root required}
	local preserve_requests=${3:?preserve request path required}
	local relative module_dir
	relative=${module#"$PROJECT_ROOT/"}
	module_dir="/run/$PROJECT_ID/$(dirname -- "$relative")"
	log "Module: $relative"
	target_chroot /usr/bin/env \
		HOME=/etc/skel \
		XDG_CONFIG_HOME=/etc/skel/.config \
		XDG_DATA_HOME=/etc/skel/.local/share \
		XDG_STATE_HOME=/etc/skel/.local/state \
		XDG_CACHE_HOME="/tmp/$PROJECT_ID-cache" \
		SETUP_ROOT="/run/$PROJECT_ID" \
		MODULE_DIR="$module_dir" \
		USERNAME="$USERNAME" \
		USER_UID="$USER_UID" \
		USER_GID="$USER_GID" \
		DISTRO="$DISTRO" \
		PACKAGE_MANAGER="$PACKAGE_MANAGER" \
		PACKAGE_RECIPE_ROOT="$package_recipe_root" \
		PROJECT_ID="$PROJECT_ID" \
		PRESERVE_REQUESTS_FILE="$preserve_requests" \
		HOME_DELETE_MODE="$HOME_DELETE_MODE" \
		bash "/run/$PROJECT_ID/$relative"
}

run_modules() {
	install_static_files
	local preserve_requests="/run/$PROJECT_ID-preserve-requests"
	: >"$TARGET_ROOT$preserve_requests"

	local modules_root="$PROJECT_ROOT/${MODULES_PATH:-modules}"
	local init_root="$modules_root/00_init"
	[[ -d $modules_root ]] || die "Modules directory not found: $modules_root"

	local setup_mount="$TARGET_ROOT/run/$PROJECT_ID"
	tracked_bind_mount "$PROJECT_ROOT" "$setup_mount"
	mount -o remount,bind,ro "$setup_mount"

	local init_modules=() modules=() discovered=() sorted=()
	local module
	shopt -s globstar nullglob
	discovered=("$modules_root"/**/*.sh)
	shopt -u globstar nullglob
	if ((${#discovered[@]} > 0)); then
		mapfile -d '' -t sorted < <(
			printf '%s\0' "${discovered[@]}" | LC_ALL=C sort -z
		)
	fi
	for module in "${sorted[@]}"; do
		if [[ $module == "$init_root/"* ]]; then
			init_modules+=("$module")
		else
			modules+=("$module")
		fi
	done
	((${#sorted[@]} > 0)) || warn "No modules found below $modules_root"

	local package_recipe_root="/run/$PROJECT_ID-package-recipes"
	for module in "${init_modules[@]}"; do
		_run_module "$module" "$package_recipe_root" "$preserve_requests"
	done

	# Resolve local recipes only after init modules establish package repositories
	# and trust, but before ordinary modules can request those recipes.
	local target_recipe_root="$TARGET_ROOT$package_recipe_root"
	log "Resolving latest local package recipes"
	rm -rf -- "$target_recipe_root"
	mkdir -p "$target_recipe_root"
	cp -a -- "$PROJECT_ROOT/packages/." "$target_recipe_root/"
	target_chroot /usr/bin/env \
		GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
		bash "/run/$PROJECT_ID/packages/update.sh" \
		"$package_recipe_root" "$DISTRO"

	for module in "${modules[@]}"; do
		_run_module "$module" "$package_recipe_root" "$preserve_requests"
	done
}
