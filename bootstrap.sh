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

ASSUME_YES=false
[[ ${1:-} == --yes ]] && ASSUME_YES=true

cleanup() {
	local status=$?
	trap - EXIT INT TERM
	cleanup_mounts
	if [[ -n ${MAPPER_DEVICE:-} && -e $MAPPER_DEVICE ]]; then
		cryptsetup close "$CRYPT_NAME" || warn "Could not close $CRYPT_NAME"
	fi
	exit "$status"
}
trap cleanup EXIT INT TERM

main() {
	require_root
	require_commands awk lsblk readlink stat
	load_bootstrap_config
	require_uefi
	require_commands \
		awk blkid btrfs chroot cryptsetup efibootmgr findmnt flock mount mountpoint umount \
		mkfs.btrfs mkfs.fat partprobe sgdisk systemd-machine-id-setup udevadm wipefs
	distro_require_bootstrap_commands
	log "Native distribution: $DISTRO ($PACKAGE_MANAGER)"

	exec 9>"/run/$PROJECT_ID.lock"
	flock -n 9 || die "Another $PROJECT_ID operation is running"

	confirm_destroy_disk "$ASSUME_YES"
	partition_disk
	format_disk
	create_initial_subvolumes
	mount_target_slot "$ROOT_A"

	install_base_system
	configure_base_system "$ROOT_A"
	write_system_config
	initialize_machine_id
	run_modules
	set_initial_password
	generate_uki "$ROOT_A"

	mount_target_home
	reconcile_home "" ""
	finalize_target_security
	activate_slot "$ROOT_A"

	log "Installation complete"
	log "Reboot, remove the installation ISO, and select '$EFI_LABEL_A' if needed"
}

main "$@"
