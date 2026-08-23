#!/usr/bin/env bash

reconcile_home() {
	local old_skel=$1
	local old_policy_dir=${2:-}
	local empty_old=

	if [[ ! -d $old_skel ]]; then
		empty_old=$(mktemp -d)
		old_skel=$empty_old
	fi

	local old_mount="$TARGET_ROOT/run/$PROJECT_ID-old-skel"
	tracked_bind_mount "$old_skel" "$old_mount"
	mount -o remount,bind,ro "$old_mount"

	local old_policy_mount="$TARGET_ROOT/run/$PROJECT_ID-old-policy"
	if [[ -n $old_policy_dir && -d $old_policy_dir ]]; then
		tracked_bind_mount "$old_policy_dir" "$old_policy_mount"
		mount -o remount,bind,ro "$old_policy_mount"
	else
		mkdir -p "$old_policy_mount"
	fi

	log "Reconciling /etc/skel into /home/$USERNAME"
	target_chroot bash "/run/$PROJECT_ID/installer/reconcile/home.sh" \
		"/run/$PROJECT_ID-old-skel" \
		/etc/skel \
		"/home/$USERNAME" \
		"/run/$PROJECT_ID-old-policy/home-strategies.tsv" \
		"/etc/$PROJECT_ID/home-strategies.tsv" \
		"$USER_UID" \
		"$USER_GID"

	[[ -z $empty_old ]] || rm -rf "$empty_old"
}
