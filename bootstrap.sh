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
RUN_MODULE_HEALTHCHECKS=false
bootstrap_options "$@"

cleanup() {
	local status=$?
	trap - EXIT INT TERM
	report_provision_failure "$status"
	cleanup_mounts
	if [[ -n ${MAPPER_DEVICE:-} && -e $MAPPER_DEVICE ]]; then
		cryptsetup close "$CRYPT_NAME" || warn "Could not close $CRYPT_NAME"
	fi
	exit "$status"
}
trap cleanup EXIT INT TERM

main() {
	require_root
	require_commands awk cp date install lsblk mountpoint mv readlink stat timeout
	load_bootstrap_config
	require_host_definition
	require_uefi
	require_commands \
		awk blkid btrfs chroot cryptsetup efibootmgr findmnt flock mount mountpoint umount \
		mkfs.btrfs mkfs.fat partprobe pivot_root sgdisk systemd-machine-id-setup timeout \
		udevadm unshare wipefs
	distro_require_bootstrap_commands
	log "Native distribution: $DISTRO ($PACKAGE_MANAGER)"

	exec 9>"/run/$PROJECT_ID.lock"
	flock -n 9 || die "Another $PROJECT_ID operation is running"
	preflight_modules

	confirm_destroy_disk "$ASSUME_YES"
	provision_checkpoint partition "$DISK"
	partition_disk
	provision_checkpoint format "$DISK"
	format_disk
	provision_checkpoint subvolumes
	create_initial_subvolumes
	mount_target_slot "$ROOT_A"

	provision_checkpoint base-system "$ROOT_A"
	install_base_system
	provision_checkpoint base-config "$ROOT_A"
	configure_base_system "$ROOT_A"
	write_system_config
	initialize_machine_id
	run_modules
	provision_checkpoint credentials
	set_initial_password
	provision_checkpoint uki "$ROOT_A"
	generate_uki "$ROOT_A"

	provision_checkpoint home
	mount_target_home
	reconcile_home "" ""
	provision_checkpoint activate "$ROOT_A"
	finalize_target_security
	activate_slot "$ROOT_A"

	provision_checkpoint complete
	log "Installation complete"
	log "Reboot, remove the installation ISO, and select '$EFI_LABEL_A' if needed"
}

main
