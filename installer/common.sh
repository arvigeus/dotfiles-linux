#!/usr/bin/env bash

log() {
	printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
	printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2
}

die() {
	printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
	exit 1
}

detect_native_distribution() {
	[[ -r /etc/os-release ]] || die "Cannot detect the native distribution: /etc/os-release is missing"

	local detected_id detected_version
	detected_id=$(
		# shellcheck disable=SC1091
		source /etc/os-release
		printf '%s\n' "${ID:-}"
	)
	detected_version=$(
		# shellcheck disable=SC1091
		source /etc/os-release
		printf '%s\n' "${VERSION_ID:-}"
	)

	case $detected_id in
	arch)
		DISTRO=arch
		PACKAGE_MANAGER=pacman
		;;
	fedora)
		[[ -n $detected_version ]] || die "Fedora VERSION_ID is missing from /etc/os-release"
		DISTRO=fedora
		PACKAGE_MANAGER=dnf
		;;
	*) die "Unsupported native distribution '$detected_id'; run from Arch Linux or Fedora" ;;
	esac
	DISTRO_VERSION_ID=$detected_version
	export DISTRO PACKAGE_MANAGER DISTRO_VERSION_ID
}

load_config() {
	local detected_project_root
	detected_project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd)
	PROJECT_ROOT=$detected_project_root
	CONFIG_FILE=${CONFIG_FILE:-"$PROJECT_ROOT/.env"}
	[[ -f $CONFIG_FILE ]] || die "Missing $CONFIG_FILE; copy .env.example to .env"

	# Project identity and distribution are internal state, never configuration.
	# Discard inherited and .env values before assigning/detecting them.
	unset PROJECT_ID DISTRO PACKAGE_MANAGER DISTRO_VERSION_ID
	set -a
	# shellcheck disable=SC1090
	source "$CONFIG_FILE"
	set +a
	PROJECT_ROOT=$detected_project_root
	unset PROJECT_ID DISTRO PACKAGE_MANAGER DISTRO_VERSION_ID
	PROJECT_ID=dotfiles
	readonly PROJECT_ID
	export PROJECT_ID
	detect_native_distribution
	# shellcheck disable=SC1090
	source "$PROJECT_ROOT/distros/$DISTRO/distro.sh"
	# shellcheck source=lib/package.sh
	source "$PROJECT_ROOT/lib/package.sh"
	distro_set_defaults

	: "${DISK:?Missing DISK in .env}"
	: "${HOSTNAME:?Missing HOSTNAME in .env}"
	: "${USERNAME:?Missing USERNAME in .env}"

	local partition_separator=
	[[ $DISK == *[0-9] ]] && partition_separator=p
	export ESP_PARTITION_NUMBER=1
	ESP_PARTITION=${ESP_PARTITION:-"${DISK}${partition_separator}1"}
	CRYPT_PARTITION=${CRYPT_PARTITION:-"${DISK}${partition_separator}2"}
	CRYPT_NAME=${CRYPT_NAME:-cryptroot}
	EFI_SIZE_MIB=${EFI_SIZE_MIB:-1024}
	ROOT_A=${ROOT_A:-@root-a}
	ROOT_B=${ROOT_B:-@root-b}
	HOME_SUBVOLUME=${HOME_SUBVOLUME:-@home}
	BTRFS_MOUNT_OPTIONS=${BTRFS_MOUNT_OPTIONS:-compress=zstd,noatime}
	USER_UID=${USER_UID:-1000}
	USER_GID=${USER_GID:-$USER_UID}
	USER_SHELL=${USER_SHELL:-/bin/bash}
	TIMEZONE=${TIMEZONE:-UTC}
	LOCALE=${LOCALE:-en_US.UTF-8}
	KEYMAP=${KEYMAP:-us}
	EFI_LABEL_A=${EFI_LABEL_A:-"$HOSTNAME A"}
	EFI_LABEL_B=${EFI_LABEL_B:-"$HOSTNAME B"}
	MODULES_PATH=${MODULES_PATH:-modules}
	HOME_DELETE_MODE=${HOME_DELETE_MODE:-unchanged}

	WORK_ROOT=${WORK_ROOT:-"/mnt/$PROJECT_ID"}
	export TARGET_ROOT="$WORK_ROOT/root"
	export TOP_LEVEL="$WORK_ROOT/top"
	export MAPPER_DEVICE="/dev/mapper/$CRYPT_NAME"
}

require_root() {
	((EUID == 0)) || die "Run this command as root"
}

require_uefi() {
	[[ -d /sys/firmware/efi/efivars ]] || die "UEFI variable services are unavailable; direct UKI booting requires UEFI"
}

require_commands() {
	local command
	for command in "$@"; do
		command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
	done
}

confirm_destroy_disk() {
	local assumed_yes=${1:-false}
	if [[ $assumed_yes == true ]]; then
		return
	fi

	printf 'This will erase %s. Type its full path to continue: ' "$DISK" >&2
	local answer
	read -r answer
	[[ $answer == "$DISK" ]] || die "Confirmation did not match $DISK"
}

MOUNT_STACK=()

tracked_mount() {
	local source=$1
	local target=$2
	shift 2
	mkdir -p "$target"
	mount "$@" "$source" "$target"
	MOUNT_STACK+=("$target")
}

tracked_bind_mount() {
	local source=$1
	local target=$2
	mkdir -p "$target"
	mount --bind "$source" "$target"
	MOUNT_STACK+=("$target")
}

tracked_rbind_mount() {
	local source=$1
	local target=$2
	mkdir -p "$target"
	mount --rbind "$source" "$target"
	mount --make-rslave "$target"
	MOUNT_STACK+=("$target")
}

TARGET_CHROOT_READY=false

prepare_target_chroot() {
	[[ $TARGET_CHROOT_READY == true ]] && return
	mkdir -p "$TARGET_ROOT/dev" "$TARGET_ROOT/proc" "$TARGET_ROOT/sys" "$TARGET_ROOT/run"
	tracked_rbind_mount /dev "$TARGET_ROOT/dev"
	tracked_mount proc "$TARGET_ROOT/proc" -t proc
	tracked_rbind_mount /sys "$TARGET_ROOT/sys"
	tracked_mount tmpfs "$TARGET_ROOT/run" -t tmpfs -o mode=0755,nosuid,nodev
	TARGET_CHROOT_READY=true
}

target_chroot() {
	prepare_target_chroot
	if [[ -r /etc/resolv.conf && -d $TARGET_ROOT/etc ]]; then
		rm -f "$TARGET_ROOT/etc/resolv.conf"
		cp -L -- /etc/resolv.conf "$TARGET_ROOT/etc/resolv.conf"
	fi
	chroot "$TARGET_ROOT" "$@"
}

cleanup_mounts() {
	local index target
	for ((index = ${#MOUNT_STACK[@]} - 1; index >= 0; index--)); do
		target=${MOUNT_STACK[$index]}
		if mountpoint -q "$target"; then
			umount --recursive "$target" || warn "Could not unmount $target"
		fi
	done
	MOUNT_STACK=()
	TARGET_CHROOT_READY=false
}

active_slot() {
	local fs_root
	fs_root=$(findmnt --noheadings --output FSROOT / | xargs)
	case $fs_root in
	"/$ROOT_A" | "$ROOT_A") printf '%s\n' "$ROOT_A" ;;
	"/$ROOT_B" | "$ROOT_B") printf '%s\n' "$ROOT_B" ;;
	*) die "Cannot identify active slot from root path: $fs_root" ;;
	esac
}

other_slot() {
	case $1 in
	"$ROOT_A") printf '%s\n' "$ROOT_B" ;;
	"$ROOT_B") printf '%s\n' "$ROOT_A" ;;
	*) die "Unknown slot: $1" ;;
	esac
}

slot_letter() {
	case $1 in
	"$ROOT_A") printf 'a\n' ;;
	"$ROOT_B") printf 'b\n' ;;
	*) die "Unknown slot: $1" ;;
	esac
}
