#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=installer/common.sh
source "$PROJECT_ROOT/installer/common.sh"
source "$PROJECT_ROOT/installer/disk.sh"
source "$PROJECT_ROOT/installer/base-system.sh"
source "$PROJECT_ROOT/installer/modules.sh"
source "$PROJECT_ROOT/installer/preserve.sh"
source "$PROJECT_ROOT/installer/uki.sh"
source "$PROJECT_ROOT/installer/efi.sh"
source "$PROJECT_ROOT/installer/home.sh"

cleanup() {
	local status=$?
	trap - EXIT INT TERM
	cleanup_mounts
	exit "$status"
}
trap cleanup EXIT INT TERM

main() {
	require_root
	require_commands findmnt stat
	load_rebuild_config
	require_uefi
	require_commands \
		awk blkid btrfs chroot cryptsetup efibootmgr findmnt flock mount mountpoint umount \
		systemctl xargs
	distro_require_rebuild_commands
	log "Native distribution: $DISTRO ($PACKAGE_MANAGER)"
	[[ -b $MAPPER_DEVICE ]] || die "$MAPPER_DEVICE is not available"
	[[ -b $ESP_PARTITION ]] || die "$ESP_PARTITION is not available"

	exec 9>"/run/$PROJECT_ID.lock"
	flock -n 9 || die "Another $PROJECT_ID operation is running"

	local active target
	active=$(active_slot)
	target=$(other_slot "$active")
	log "Active slot: $active; clean target: $target"

	prepare_empty_slot "$target"
	mount_target_slot "$target"
	install_base_system
	configure_base_system "$target"
	write_system_config
	copy_login_password
	run_modules
	preserve_active_state
	generate_uki "$target"

	mount_target_home
	reconcile_home /etc/skel "/etc/$PROJECT_ID"
	finalize_target_security
	activate_slot "$target" "$active"

	log "Built $target and placed it first in UEFI BootOrder"
	log "The next reboot will enter $target; $active remains available from the firmware menu"

	local answer=
	if [[ -r /dev/tty ]]; then
		read -r -p "Reboot into $target now? [y/N]: " answer </dev/tty
	fi
	if [[ $answer == [yY] || $answer == [yY][eE][sS] ]]; then
		cleanup_mounts
		log "Rebooting into $target"
		systemctl reboot
	else
		log "Reboot postponed; $target remains selected for the next boot"
	fi
}

main "$@"
