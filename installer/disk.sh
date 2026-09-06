#!/usr/bin/env bash

partition_disk() {
	log "Partitioning $DISK"
	wipefs --all --force "$DISK"
	sgdisk --zap-all "$DISK"
	sgdisk --new="1:1MiB:+${EFI_SIZE_MIB}MiB" --typecode=1:ef00 --change-name=1:ESP "$DISK"
	sgdisk --new=2:0:0 --typecode=2:8309 --change-name=2:cryptroot "$DISK"
	partprobe "$DISK"
	udevadm settle --timeout=120

	[[ -b $ESP_PARTITION ]] || die "ESP did not appear at $ESP_PARTITION"
	[[ -b $CRYPT_PARTITION ]] || die "Encrypted partition did not appear at $CRYPT_PARTITION"
}

format_disk() {
	log "Formatting EFI and encrypted Btrfs filesystems"
	mkfs.fat -F 32 -n EFI "$ESP_PARTITION"
	cryptsetup luksFormat --type luks2 "$CRYPT_PARTITION"
	cryptsetup open "$CRYPT_PARTITION" "$CRYPT_NAME"
	mkfs.btrfs -f -L "$HOSTNAME" "$MAPPER_DEVICE"
}

create_initial_subvolumes() {
	mkdir -p "$TOP_LEVEL"
	tracked_mount "$MAPPER_DEVICE" "$TOP_LEVEL"

	btrfs subvolume create "$TOP_LEVEL/$ROOT_A"
	btrfs subvolume create "$TOP_LEVEL/$ROOT_B"
	btrfs subvolume create "$TOP_LEVEL/$HOME_SUBVOLUME"

	cleanup_mounts
}

prepare_empty_slot() {
	local slot=$1

	mkdir -p "$TOP_LEVEL"
	tracked_mount "$MAPPER_DEVICE" "$TOP_LEVEL"

	if btrfs subvolume show "$TOP_LEVEL/$slot" >/dev/null 2>&1; then
		log "Deleting inactive slot $slot"
		btrfs subvolume delete "$TOP_LEVEL/$slot"
	fi
	btrfs subvolume create "$TOP_LEVEL/$slot"

	cleanup_mounts
}

mount_target_slot() {
	local slot=$1
	mkdir -p "$TARGET_ROOT"
	tracked_mount "$MAPPER_DEVICE" "$TARGET_ROOT" -o "$BTRFS_MOUNT_OPTIONS,subvol=$slot"
	tracked_mount "$ESP_PARTITION" "$TARGET_ROOT/efi"
}

mount_target_home() {
	tracked_mount "$MAPPER_DEVICE" "$TARGET_ROOT/home" -o "$BTRFS_MOUNT_OPTIONS,subvol=$HOME_SUBVOLUME"
}
