#!/usr/bin/env bash

install_static_files() {
	local files_root="$PROJECT_ROOT/files"
	[[ -d $files_root ]] || return 0

	log "Installing static filesystem overlay"
	cp -R --no-preserve=ownership -- "$files_root/." "$TARGET_ROOT/"
}

run_modules() {
	install_static_files
	local preserve_requests="/run/$PROJECT_ID-preserve-requests"
	: >"$TARGET_ROOT$preserve_requests"

	local modules_root="$PROJECT_ROOT/${MODULES_PATH:-modules}"
	[[ -d $modules_root ]] || die "Modules directory not found: $modules_root"

	local setup_mount="$TARGET_ROOT/run/$PROJECT_ID"
	tracked_bind_mount "$PROJECT_ROOT" "$setup_mount"
	mount -o remount,bind,ro "$setup_mount"

	# Resolve local recipes in an ephemeral copy. The checkout remains unchanged,
	# while every bootstrap/rebuild builds the latest stable release or branch
	# head with checksums calculated before package tooling runs.
	local package_recipe_root="/run/$PROJECT_ID-package-recipes"
	local target_recipe_root="$TARGET_ROOT$package_recipe_root"
	log "Resolving latest local package recipes"
	rm -rf -- "$target_recipe_root"
	mkdir -p "$target_recipe_root"
	cp -a -- "$PROJECT_ROOT/packages/." "$target_recipe_root/"
	target_chroot /usr/bin/env \
		GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
		bash "/run/$PROJECT_ID/packages/update.sh" \
		"$package_recipe_root" "$DISTRO"

	local modules=()
	local module relative module_dir
	shopt -s globstar nullglob
	modules=("$modules_root"/**/*.sh)
	shopt -u globstar nullglob

	((${#modules[@]} > 0)) || warn "No modules found below $modules_root"

	for module in "${modules[@]}"; do
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
	done
}
