#!/usr/bin/env bash

_run_module() {
	local phase=${1:?module phase required}
	local module=${2:?module path required}
	local module_id=${3:?module id required}
	local plan_file=${4:?module plan path required}
	local preserve_requests=${5:?preserve request path required}
	local relative module_dir
	relative=${module#"$PROJECT_ROOT/"}
	module_dir="/run/$PROJECT_ID/$(dirname -- "$relative")"
	local deadline
	case $phase in
	plan) deadline=60 ;;
	apply) deadline=1800 ;;
	healthcheck) deadline=180 ;;
	*) die "Unknown module phase: $phase" ;;
	esac
	log "Module $phase: $module_id"
	if [[ ${MODULE_PREFLIGHT:-false} == true ]]; then
		/usr/bin/env \
			HOME="/tmp/$PROJECT_ID-preflight-home" \
			XDG_CONFIG_HOME="/tmp/$PROJECT_ID-preflight-home/.config" \
			XDG_DATA_HOME="/tmp/$PROJECT_ID-preflight-home/.local/share" \
			XDG_STATE_HOME="/tmp/$PROJECT_ID-preflight-home/.local/state" \
			XDG_CACHE_HOME="/tmp/$PROJECT_ID-preflight-cache" \
			SETUP_ROOT="$PROJECT_ROOT" \
			MODULE_DIR="$(dirname -- "$module")" \
			MODULE_ID="$module_id" \
			MODULE_PHASE="$phase" \
			MODULE_PLAN_FILE="$plan_file" \
			DESKTOP="${DESKTOP:-plasma}" HOST_PROFILE="${HOST_PROFILE:-$HOSTNAME}" \
			USERNAME="$USERNAME" USER_UID="$USER_UID" USER_GID="$USER_GID" \
			DISTRO="$DISTRO" PACKAGE_MANAGER="$PACKAGE_MANAGER" PROJECT_ID="$PROJECT_ID" \
			PRESERVE_REQUESTS_FILE="$preserve_requests" \
			HOME_DELETE_MODE="$HOME_DELETE_MODE" \
			timeout --foreground --signal=INT --kill-after=5s "$deadline" \
			bash "$module"
		return
	fi

	target_namespace /usr/bin/env \
		HOME=/etc/skel \
		XDG_CONFIG_HOME=/etc/skel/.config \
		XDG_DATA_HOME=/etc/skel/.local/share \
		XDG_STATE_HOME=/etc/skel/.local/state \
		XDG_CACHE_HOME="/tmp/$PROJECT_ID-cache" \
		SETUP_ROOT="/run/$PROJECT_ID" \
		MODULE_DIR="$module_dir" \
		MODULE_ID="$module_id" \
		MODULE_PHASE="$phase" \
		MODULE_PLAN_FILE="$plan_file" \
		DESKTOP="${DESKTOP:-plasma}" HOST_PROFILE="${HOST_PROFILE:-$HOSTNAME}" \
		USERNAME="$USERNAME" \
		USER_UID="$USER_UID" \
		USER_GID="$USER_GID" \
		DISTRO="$DISTRO" \
		PACKAGE_MANAGER="$PACKAGE_MANAGER" \
		PROJECT_ID="$PROJECT_ID" \
		PRESERVE_REQUESTS_FILE="$preserve_requests" \
		HOME_DELETE_MODE="$HOME_DELETE_MODE" \
		timeout --foreground --signal=INT --kill-after=30s "$deadline" \
		bash "/run/$PROJECT_ID/$relative"
}

_module_checkpoint() {
	local phase=${1:?checkpoint phase required}
	local detail=${2:-}
	provision_checkpoint "$phase" "$detail"
}

_module_resolve_path() {
	local selector=${1:?module selector required}
	[[ $selector =~ ^[a-zA-Z0-9][a-zA-Z0-9._/-]*$ &&
		$selector != */ && $selector != *//* && $selector != .* &&
		$selector != */.* && $selector != *../* && $selector != */.. ]] || {
		printf 'Invalid module selector: %s\n' "$selector" >&2
		return 1
	}

	local modules_root="$PROJECT_ROOT/${MODULES_PATH:-modules}"
	if [[ -f $modules_root/$selector/module.sh && ! -L $modules_root/$selector/module.sh ]]; then
		MODULE_RESOLVED_PATH="$modules_root/$selector/module.sh"
	elif [[ -f $modules_root/$selector.sh && ! -L $modules_root/$selector.sh ]]; then
		MODULE_RESOLVED_PATH="$modules_root/$selector.sh"
	else
		printf 'Unknown module selected by host %s: %s\n' "$HOSTNAME" "$selector" >&2
		return 1
	fi
}

_load_host_modules() {
	local host="$PROJECT_ROOT/hosts/${HOST_PROFILE:-$HOSTNAME}.sh"
	[[ -f $host && ! -L $host ]] || die "Host definition not found: $host"
	local output
	if [[ ${MODULE_PREFLIGHT:-false} == true ]]; then
		output=$(mktemp "/tmp/$PROJECT_ID-host.XXXXXX")
	else
		output=$(mktemp "$TARGET_ROOT/run/$PROJECT_ID-host.XXXXXX")
	fi
	if ! (
		set -Eeuo pipefail
		modules=()
		# shellcheck disable=SC1090
		source "$host"
		((${#modules[@]} > 0)) || {
			printf 'Host %s selects no modules\n' "$host" >&2
			exit 1
		}
		printf '%s\0' "${modules[@]}" >"$output"
	); then
		rm -f -- "$output"
		die "Could not load host definition: $host"
	fi
	mapfile -d '' -t HOST_MODULES <"$output"
	rm -f -- "$output"
}

declare -A MODULE_STATES=()
declare -A MODULE_FILE_OWNERS=()
SELECTED_MODULE_IDS=()
SELECTED_MODULE_FILES=()
SELECTED_MODULE_DIRS=()

_register_module_files() {
	local module_id=${1:?module id required}
	local module_dir=${2:?module directory required}
	local files="$module_dir/files"
	[[ -d $files ]] || return 0
	if find "$files" -type l -print -quit | grep -q .; then
		printf 'Module %s files overlay contains a symlink; use a module_apply helper instead\n' \
			"$module_id" >&2
		return 1
	fi

	local path relative owner
	while IFS= read -r -d '' path; do
		relative=${path#"$files/"}
		owner=${MODULE_FILE_OWNERS[$relative]:-}
		[[ -z $owner || $owner == "$module_id" ]] || {
			printf 'Module file conflict at /%s: %s and %s\n' \
				"$relative" "$owner" "$module_id" >&2
			return 1
		}
		MODULE_FILE_OWNERS[$relative]=$module_id
	done < <(find "$files" -type f -print0 | LC_ALL=C sort -z)
}

_resolve_module() {
	local selector=${1:?module selector required}
	case ${MODULE_STATES[$selector]:-unseen} in
	done) return 0 ;;
	visiting)
		printf 'Module dependency/member cycle at %s\n' "$selector" >&2
		return 1
		;;
	esac
	MODULE_STATES[$selector]=visiting

	_module_resolve_path "$selector" || return
	local module=$MODULE_RESOLVED_PATH
	local scratch_plan=${MODULE_SCRATCH_PLAN:-"/run/$PROJECT_ID-module-plan.tsv"}
	_run_module plan "$module" "$selector" "$scratch_plan" "$PRESERVE_REQUESTS" || return

	local record value is_leaf=false skipped=false
	local members=() requires=() sources=() packages=()
	while IFS=$'\t' read -r record value; do
		case $record in
		leaf) is_leaf=true ;;
		skip)
			skipped=true
			log "Skipping module $selector: $value"
			;;
		member) members+=("$value") ;;
		require) requires+=("$value") ;;
		source) sources+=("$value") ;;
		package) packages+=("$value") ;;
		'') ;;
		*)
			printf 'Unknown plan record from %s: %s\n' "$selector" "$record" >&2
			return 1
			;;
		esac
	done <"$TARGET_ROOT$scratch_plan"

	if [[ $skipped == true ]]; then
		MODULE_STATES[$selector]='done'
		return
	fi

	local child requirement
	if ((${#members[@]} > 0)); then
		[[ $is_leaf == false ]] || {
			printf 'Module %s cannot be both aggregate and leaf\n' "$selector" >&2
			return 1
		}
		for child in "${members[@]}"; do
			_resolve_module "$selector/$child" || return
		done
		MODULE_STATES[$selector]='done'
		return
	fi

	[[ $is_leaf == true ]] || {
		printf 'Module %s produced neither a leaf nor members\n' "$selector" >&2
		return 1
	}
	for requirement in "${requires[@]}"; do
		_resolve_module "$requirement" || return
	done

	local relative module_dir source package
	relative=${module#"$PROJECT_ROOT/"}
	if [[ ${MODULE_PREFLIGHT:-false} == true ]]; then
		module_dir=$(dirname -- "$module")
	else
		module_dir="/run/$PROJECT_ID/$(dirname -- "$relative")"
	fi
	_register_module_files "$selector" "$(dirname -- "$module")" || return
	SELECTED_MODULE_IDS+=("$selector")
	SELECTED_MODULE_FILES+=("$module")
	SELECTED_MODULE_DIRS+=("$(dirname -- "$module")")
	for source in "${sources[@]}"; do
		printf '%s\t%s\tsource:%s\n' "$selector" "$module_dir" "$source" \
			>>"$TARGET_ROOT$PACKAGE_PLAN"
	done
	for package in "${packages[@]}"; do
		printf '%s\t%s\t%s\n' "$selector" "$module_dir" "$package" \
			>>"$TARGET_ROOT$PACKAGE_PLAN"
	done
	MODULE_STATES[$selector]='done'
}

preflight_modules() (
	set -Eeuo pipefail
	MODULE_PREFLIGHT=true
	# Package source plugins are sourced while validating the generated plan.
	# The installer process itself has PROJECT_ROOT, while plugins consistently
	# address shared helpers through SETUP_ROOT just as they do in the target.
	SETUP_ROOT=$PROJECT_ROOT
	export SETUP_ROOT
	TARGET_ROOT=
	PRESERVE_REQUESTS=$(mktemp "/tmp/$PROJECT_ID-preflight-preserve.XXXXXX")
	PACKAGE_PLAN=$(mktemp "/tmp/$PROJECT_ID-preflight-packages.XXXXXX")
	MODULE_SCRATCH_PLAN=$(mktemp "/tmp/$PROJECT_ID-preflight-module.XXXXXX")
	trap 'rm -rf -- "/tmp/$PROJECT_ID-preflight-home" "/tmp/$PROJECT_ID-preflight-cache"; rm -f -- "$PRESERVE_REQUESTS" "$PACKAGE_PLAN" "$MODULE_SCRATCH_PLAN"' EXIT
	MODULE_STATES=()
	MODULE_FILE_OWNERS=()
	SELECTED_MODULE_IDS=()
	SELECTED_MODULE_FILES=()
	SELECTED_MODULE_DIRS=()
	_load_host_modules

	log "Preflighting profile: ${HOST_PROFILE:-$HOSTNAME} (desktop ${DESKTOP:-plasma})"
	local selector
	for selector in "${HOST_MODULES[@]}"; do
		_resolve_module "$selector" || exit 1
	done
	((${#SELECTED_MODULE_IDS[@]} > 0)) || die "Host $HOSTNAME resolved to no applicable modules"
	_pkg_validate_plan "$PACKAGE_PLAN" || exit 1
	log "Preflight passed: ${#SELECTED_MODULE_IDS[@]} applicable leaf modules"
)

_prepare_module_packages() {
	local target_recipes="$TARGET_ROOT/run/$PROJECT_ID-package-recipes"
	rm -rf -- "$target_recipes"
	mkdir -p "$target_recipes"

	local index module_id module_dir destination
	for ((index = 0; index < ${#SELECTED_MODULE_IDS[@]}; index++)); do
		module_id=${SELECTED_MODULE_IDS[$index]}
		module_dir=${SELECTED_MODULE_DIRS[$index]}
		[[ -d $module_dir/packages ]] || continue
		destination="$target_recipes/$module_id"
		mkdir -p "$destination"
		cp -a -- "$module_dir/packages/." "$destination/"
		_module_checkpoint recipes "$module_id"
		log "Resolving local package recipes for $module_id"
		target_chroot /usr/bin/env \
			GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
			timeout --foreground --signal=INT --kill-after=30s 900 \
			bash "/run/$PROJECT_ID/packages/update.sh" \
			"/run/$PROJECT_ID-package-recipes/$module_id" "$DISTRO" \
			2>&1 | tee "$TARGET_ROOT/var/log/$PROJECT_ID/recipe-${module_id//\//_}.log"
		local metadata_dir="$TARGET_ROOT/var/log/$PROJECT_ID/package-recipes/$module_id"
		mkdir -p "$metadata_dir"
		(cd "$destination" && find . -type f \( -name PKGBUILD -o -name '*.spec' -o -name sources.sha256 \) -exec cp --parents -- {} "$metadata_dir/" \;)
	done
}

_apply_package_plan() {
	log "Installing the planned package set"
	target_namespace /usr/bin/env \
		HOME=/root \
		SETUP_ROOT="/run/$PROJECT_ID" \
		DISTRO="$DISTRO" \
		PACKAGE_MANAGER="$PACKAGE_MANAGER" \
		PROJECT_ID="$PROJECT_ID" \
		timeout --foreground --signal=INT --kill-after=30s 7200 \
		bash "/run/$PROJECT_ID/installer/apply-package-plan.sh" "$PACKAGE_PLAN" \
		2>&1 | tee "$TARGET_ROOT/var/log/$PROJECT_ID/packages.log"
}

run_modules() {
	local modules_root="$PROJECT_ROOT/${MODULES_PATH:-modules}"
	[[ -d $modules_root ]] || die "Modules directory not found: $modules_root"

	local setup_mount="$TARGET_ROOT/run/$PROJECT_ID"
	tracked_bind_mount "$PROJECT_ROOT" "$setup_mount"
	mount -o remount,bind,ro "$setup_mount"

	PRESERVE_REQUESTS="/run/$PROJECT_ID-preserve-requests"
	PACKAGE_PLAN="/run/$PROJECT_ID-package-plan.tsv"
	MODULE_STATES=()
	MODULE_FILE_OWNERS=()
	SELECTED_MODULE_IDS=()
	SELECTED_MODULE_FILES=()
	SELECTED_MODULE_DIRS=()
	: >"$TARGET_ROOT$PRESERVE_REQUESTS"
	: >"$TARGET_ROOT$PACKAGE_PLAN"
	_load_host_modules

	log "Planning profile: ${HOST_PROFILE:-$HOSTNAME} (desktop ${DESKTOP:-plasma})"
	_module_checkpoint planning "$HOSTNAME"
	local selector
	for selector in "${HOST_MODULES[@]}"; do
		_resolve_module "$selector"
	done
	((${#SELECTED_MODULE_IDS[@]} > 0)) || die "Host $HOSTNAME resolved to no applicable modules"
	log "Plan contains ${#SELECTED_MODULE_IDS[@]} leaf modules"
	mkdir -p "$TARGET_ROOT/var/log/$PROJECT_ID"
	cp -- "$TARGET_ROOT$PACKAGE_PLAN" "$TARGET_ROOT/var/log/$PROJECT_ID/package-plan.tsv"

	_module_checkpoint recipes
	_prepare_module_packages
	_module_checkpoint packages
	_apply_package_plan

	local index total=${#SELECTED_MODULE_IDS[@]}
	for ((index = 0; index < total; index++)); do
		_module_checkpoint module "${SELECTED_MODULE_IDS[$index]}"
		log "Applying module $((index + 1))/$total: ${SELECTED_MODULE_IDS[$index]}"
		_run_module apply \
			"${SELECTED_MODULE_FILES[$index]}" \
			"${SELECTED_MODULE_IDS[$index]}" \
			"/run/$PROJECT_ID-module-plan.tsv" \
			"$PRESERVE_REQUESTS" \
			2>&1 | tee "$TARGET_ROOT/var/log/$PROJECT_ID/module-${SELECTED_MODULE_IDS[$index]//\//_}.log"
	done

	if [[ ${RUN_MODULE_HEALTHCHECKS:-false} == true ]]; then
		for ((index = 0; index < total; index++)); do
			_module_checkpoint healthcheck "${SELECTED_MODULE_IDS[$index]}"
			log "Healthcheck $((index + 1))/$total: ${SELECTED_MODULE_IDS[$index]}"
			_run_module healthcheck \
				"${SELECTED_MODULE_FILES[$index]}" \
				"${SELECTED_MODULE_IDS[$index]}" \
				"/run/$PROJECT_ID-module-plan.tsv" \
				"$PRESERVE_REQUESTS"
		done
	fi
	_module_checkpoint complete
}
