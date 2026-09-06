#!/usr/bin/env bash
# shellcheck disable=SC2034 # shared with other sourced installer components

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

initialize_project() {
	PROJECT_ROOT=$(cd -- "${PROJECT_ROOT:?project root is required}" && pwd)
	unset PROJECT_ID DISTRO PACKAGE_MANAGER DISTRO_VERSION_ID
	PROJECT_ID=system
	readonly PROJECT_ID
	export PROJECT_ID
	rm -f -- "/run/$PROJECT_ID-provision-state" "/run/$PROJECT_ID-provision-state.tmp"
	detect_native_distribution
	# shellcheck disable=SC1090
	source "$PROJECT_ROOT/installer/distros/$DISTRO/backend.sh"
	# shellcheck disable=SC1090
	source "$PROJECT_ROOT/sources/$DISTRO/$PACKAGE_MANAGER.sh"
	# shellcheck source=lib/package.sh
	source "$PROJECT_ROOT/lib/package.sh"
	SYSTEM_CONFIG=/etc/$PROJECT_ID/config
}

prompt_value() {
	local -n destination=$1
	local prompt=$2 default=${3:-} value
	if [[ -n $default ]]; then
		read -r -p "$prompt [$default]: " value </dev/tty
		value=${value:-$default}
	else
		read -r -p "$prompt: " value </dev/tty
	fi
	destination=$value
}

prompt_bootstrap_config() {
	[[ -r /dev/tty ]] || die "Interactive bootstrap requires a terminal"
	log "Available installation disks"
	lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF == "disk" { $NF=""; sub(/[[:space:]]+$/, ""); print "  " $0 }'

	prompt_value DISK "Disk to erase (full device path)"
	DISK=$(readlink -f -- "$DISK")
	[[ -b $DISK ]] || die "Installation disk is not a block device: $DISK"
	[[ $(lsblk -dnro TYPE "$DISK") == disk ]] || die "Select a complete disk, not a partition: $DISK"

	prompt_value HOSTNAME "Host profile and hostname" zephyrus
	[[ $HOSTNAME =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || die "Invalid hostname: $HOSTNAME"
	prompt_value USERNAME "Login username" user
	[[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username: $USERNAME"
	prompt_value TIMEZONE "Timezone" UTC
	[[ $TIMEZONE =~ ^[a-zA-Z0-9_+.-]+(/[a-zA-Z0-9_+.-]+)*$ && $TIMEZONE != *..* ]] ||
		die "Invalid timezone: $TIMEZONE"
	[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "Unknown timezone: $TIMEZONE"
	prompt_value LOCALE "Locale" en_US.UTF-8
	[[ $LOCALE =~ ^[a-zA-Z0-9_.@-]+$ ]] || die "Invalid locale: $LOCALE"
	prompt_value KEYMAP "Console keymap" us
	[[ $KEYMAP =~ ^[a-zA-Z0-9_.+-]+$ ]] || die "Invalid keymap: $KEYMAP"

	printf '\nInstallation summary:\n'
	printf '  Distribution: %s\n' "$DISTRO"
	printf '  Disk:         %s (will be erased)\n' "$DISK"
	printf '  Hostname:     %s\n' "$HOSTNAME"
	printf '  User:         %s (UID %s)\n' "$USERNAME" 1000
	printf '  Timezone:     %s\n' "$TIMEZONE"
	printf '  Locale:       %s\n' "$LOCALE"
	printf '  Keymap:       %s\n\n' "$KEYMAP"
}

load_installed_config() {
	[[ -f $SYSTEM_CONFIG ]] || die "Missing installed-system configuration: $SYSTEM_CONFIG"
	[[ $(stat -c %u "$SYSTEM_CONFIG") == 0 ]] || die "$SYSTEM_CONFIG must be owned by root"
	local permissions
	permissions=$(stat -c %a "$SYSTEM_CONFIG")
	[[ ${permissions: -2:1} != [2367] && ${permissions: -1} != [2367] ]] ||
		die "$SYSTEM_CONFIG must not be group- or world-writable"
	# shellcheck disable=SC1090
	source "$SYSTEM_CONFIG"
}

finalize_config() {
	: "${DISK:?Missing installation disk}"
	: "${HOSTNAME:?Missing hostname}"
	: "${USERNAME:?Missing username}"
	: "${TIMEZONE:?Missing timezone}"
	: "${LOCALE:?Missing locale}"
	: "${KEYMAP:?Missing keymap}"

	[[ $DISK == /dev/* && $DISK != *..* && -b $DISK ]] ||
		die "Configured installation disk is not a block device below /dev: $DISK"
	[[ $(lsblk -dnro TYPE "$DISK") == disk ]] ||
		die "Configured installation disk is not a complete disk: $DISK"
	[[ $HOSTNAME =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || die "Invalid hostname: $HOSTNAME"
	[[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username: $USERNAME"
	[[ $TIMEZONE =~ ^[a-zA-Z0-9_+.-]+(/[a-zA-Z0-9_+.-]+)*$ && $TIMEZONE != *..* ]] ||
		die "Invalid timezone: $TIMEZONE"
	[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "Unknown timezone: $TIMEZONE"
	[[ $LOCALE =~ ^[a-zA-Z0-9_.@-]+$ ]] || die "Invalid locale: $LOCALE"
	[[ $KEYMAP =~ ^[a-zA-Z0-9_.+-]+$ ]] || die "Invalid keymap: $KEYMAP"

	local partition_separator=
	[[ $DISK == *[0-9] ]] && partition_separator=p
	export ESP_PARTITION_NUMBER=1
	ESP_PARTITION="${DISK}${partition_separator}1"
	CRYPT_PARTITION="${DISK}${partition_separator}2"
	CRYPT_NAME=cryptroot
	EFI_SIZE_MIB=1024
	ROOT_A=@root-a
	ROOT_B=@root-b
	HOME_SUBVOLUME=@home
	BTRFS_MOUNT_OPTIONS=compress=zstd,noatime
	USER_UID=1000
	USER_GID=$USER_UID
	USER_SHELL=/bin/bash
	EFI_LABEL_A="$HOSTNAME A"
	EFI_LABEL_B="$HOSTNAME B"
	MODULES_PATH=modules
	HOME_DELETE_MODE=unchanged

	WORK_ROOT="/mnt/$PROJECT_ID"
	export TARGET_ROOT="$WORK_ROOT/root"
	export TOP_LEVEL="$WORK_ROOT/top"
	export MAPPER_DEVICE="/dev/mapper/$CRYPT_NAME"
	distro_set_defaults
}

require_host_definition() {
	local host="$PROJECT_ROOT/hosts/${HOSTNAME:?Missing hostname}.sh"
	[[ -f $host && ! -L $host ]] ||
		die "Host definition not found: $host"
}

load_bootstrap_config() {
	initialize_project
	prompt_bootstrap_config
	finalize_config
}

load_rebuild_config() {
	initialize_project
	load_installed_config
	finalize_config
	local root_source
	root_source=$(findmnt --noheadings --output SOURCE /)
	root_source=${root_source%%\[*}
	[[ $root_source == "$MAPPER_DEVICE" ]] ||
		die "The running root does not use the configured mapper $MAPPER_DEVICE"
}

write_system_config() {
	local destination="$TARGET_ROOT$SYSTEM_CONFIG"
	install -d -m 0755 "$(dirname -- "$destination")"
	{
		printf '# Generated during interactive bootstrap; contains no secrets.\n'
		printf 'DISK=%q\n' "$DISK"
		printf 'HOSTNAME=%q\n' "$HOSTNAME"
		printf 'USERNAME=%q\n' "$USERNAME"
		printf 'TIMEZONE=%q\n' "$TIMEZONE"
		printf 'LOCALE=%q\n' "$LOCALE"
		printf 'KEYMAP=%q\n' "$KEYMAP"
	} >"$destination"
	chmod 0644 "$destination"
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

provision_checkpoint() {
	local phase=${1:?checkpoint phase required}
	local detail=${2:-}
	local runtime_state="/run/${PROJECT_ID:?project ID required}-provision-state"
	local temporary="$runtime_state.tmp"
	{
		printf 'phase=%q\n' "$phase"
		printf 'detail=%q\n' "$detail"
		printf 'updated_at=%q\n' "$(date --iso-8601=seconds)"
	} >"$temporary"
	mv -f -- "$temporary" "$runtime_state"

	if [[ -n ${TARGET_ROOT:-} ]] && mountpoint -q "$TARGET_ROOT"; then
		local state_dir="$TARGET_ROOT/var/lib/$PROJECT_ID"
		install -d -m 0755 "$state_dir"
		cp -- "$runtime_state" "$state_dir/provision-state"
	fi
}

report_provision_failure() {
	local status=${1:?exit status required}
	((status != 0)) || return 0
	warn "Provisioning failed with exit status $status"
	if [[ -z ${PROJECT_ID:-} ]]; then
		warn "No checkpoint was recorded; failure occurred before project initialization"
		return 0
	fi
	local state="/run/$PROJECT_ID-provision-state"
	if [[ -f $state ]]; then
		warn "Last checkpoint:"
		while IFS= read -r line; do
			printf '  %s\n' "$line" >&2
		done <"$state"
	else
		warn "No checkpoint was recorded; failure occurred during initial validation"
	fi
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

# Run commands that need to create nested namespaces from a real filesystem
# root. A plain chroot is deliberately barred by the kernel from creating a
# user namespace, which prevents Flatpak/bubblewrap from deploying extra-data
# applications. The private mount namespace also contains any mounts made by a
# module so a failed sandbox cannot leave the installer's mount stack busy.
target_namespace() {
	prepare_target_chroot
	unshare --mount --fork --kill-child -- \
		bash "$PROJECT_ROOT/installer/pivot-root.sh" \
		"$TARGET_ROOT" "/run/$PROJECT_ID/installer/pivot-root.sh" "$@"
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
