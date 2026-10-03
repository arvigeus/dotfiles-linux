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
		read -r -p "$prompt [$default]: " value <&3
		value=${value:-$default}
	else
		read -r -p "$prompt: " value <&3
	fi
	destination=$value
}

# Numbered menus write the selected literal value through a nameref.
# Prompts use fd 3, which defaults to /dev/tty but can be supplied in tests.
prompt_select() {
	local -n selection=$1
	local label=$2 default=$3 answer index
	shift 3
	local choices=("$@")
	((${#choices[@]} > 0)) || die "No choices available for $label"
	printf '%s:\n' "$label" >&2
	for index in "${!choices[@]}"; do
		printf '  %d) %s\n' "$((index + 1))" "${choices[$index]}" >&2
	done
	while true; do
		printf 'Select [ %s ]: ' "$default" >&2
		read -r answer <&3 || die "No selection received for $label"
		answer=${answer:-$default}
		if [[ $answer =~ ^[1-9][0-9]*$ ]] && ((${#answer} < 5)) &&
			((answer <= ${#choices[@]})); then
			selection=${choices[$((answer - 1))]}
			return
		fi
		printf 'Enter a number from 1 to %d.\n' "${#choices[@]}" >&2
	done
}

bootstrap_options() {
	while (($#)); do
		case $1 in
		-h | --help)
			cat <<'USAGE'
Usage: bootstrap.sh [--disk DEVICE] [--host-profile PROFILE] [--desktop plasma|hyprland]
                    [--hostname NAME] [--username NAME] [--timezone ZONE]
                    [--locale LOCALE] [--keymap MAP] [--healthchecks]
                    [--non-interactive] [--yes]

Disk/profile/desktop use numbered menus. Other answers have Enter defaults.
Each answer also supports a SYSTEM_* environment override; CLI values win.
--non-interactive requires disk/profile/desktop overrides and defaults the rest.
LUKS and login passwords are still requested through native terminal prompts.
--yes explicitly skips the full-disk-path destruction confirmation.
USAGE
			exit 0
			;;
		--yes)
			ASSUME_YES=true
			shift
			;;
		--healthchecks)
			RUN_MODULE_HEALTHCHECKS=true
			shift
			;;
		--non-interactive)
			SYSTEM_NONINTERACTIVE=true
			shift
			;;
		--disk | --host-profile | --hostname | --desktop | --username | --timezone | --locale | --keymap)
			(($# >= 2)) && [[ -n $2 ]] || die "$1 requires a value"
			local option=${1#--}
			option=${option//-/_}
			printf -v "SYSTEM_${option^^}" '%s' "$2"
			shift 2
			;;
		*) die "Unknown bootstrap option: $1" ;;
		esac
	done
}

bootstrap_value() {
	local name=$1 label=$2 default=$3 override="SYSTEM_$1"
	if [[ -n ${!override:-} ]]; then
		printf -v "$name" '%s' "${!override}"
	else
		prompt_value "$name" "$label" "$default"
	fi
}

validate_desktop() {
	case ${DESKTOP:-} in
	plasma) ;;
	hyprland)
		[[ $DISTRO == arch ]] || die "Zephyrus Hyprland currently requires Arch: Fedora's packaged Hyprland/Qt terminal runtime is not yet compatible with its Lua session. Plasma supports both distributions."
		;;
	*) die "Unsupported desktop: ${DESKTOP:-unset} (choose plasma or hyprland)" ;;
	esac
}

installation_summary() {
	printf '\nInstallation summary:\n'
	printf '  Distribution: %s\n' "$DISTRO"
	printf '  Disk:         %s — ALL partitions and data will be erased\n' "$DISK"
	lsblk -dno SIZE,MODEL "$DISK"
	printf '  Host profile: %s\n' "$HOST_PROFILE"
	printf '  Hostname:     %s\n' "$HOSTNAME"
	printf '  Desktop:      %s\n' "$DESKTOP"
	printf '  User:         %s (UID %s)\n' "$USERNAME" 1000
	printf '  Timezone:     %s\n' "$TIMEZONE"
	printf '  Locale:       %s\n' "$LOCALE"
	printf '  Keymap:       %s\n' "$KEYMAP"
	printf '  Storage:      1 GiB EFI + encrypted Btrfs, two root slots and shared home\n\n'
}

prompt_bootstrap_config() {
	local disks=() profiles=() path choice default_profile=1
	if [[ ${SYSTEM_NONINTERACTIVE:-false} == true ]]; then
		[[ -n ${SYSTEM_DISK:-} && -n ${SYSTEM_HOST_PROFILE:-} && -n ${SYSTEM_DESKTOP:-} ]] ||
			die "--non-interactive requires disk, host-profile and desktop overrides"
		SYSTEM_HOSTNAME=${SYSTEM_HOSTNAME:-${SYSTEM_HOST_PROFILE//_/-}}
		SYSTEM_USERNAME=${SYSTEM_USERNAME:-user}
		SYSTEM_TIMEZONE=${SYSTEM_TIMEZONE:-UTC}
		SYSTEM_LOCALE=${SYSTEM_LOCALE:-en_US.UTF-8}
		SYSTEM_KEYMAP=${SYSTEM_KEYMAP:-us}
	fi
	# Open a terminal only when some configuration needs interaction.
	if [[ -z ${SYSTEM_DISK:-} || -z ${SYSTEM_HOST_PROFILE:-} || -z ${SYSTEM_DESKTOP:-} ||
		-z ${SYSTEM_HOSTNAME:-} || -z ${SYSTEM_USERNAME:-} || -z ${SYSTEM_TIMEZONE:-} ||
		-z ${SYSTEM_LOCALE:-} || -z ${SYSTEM_KEYMAP:-} ]]; then
		exec 3</dev/tty || die "Supply all --configuration options when no terminal is available"
	fi
	if [[ -n ${SYSTEM_DISK:-} ]]; then
		DISK=$SYSTEM_DISK
	else
		while read -r path; do
			disks+=("$path")
		done < <(lsblk -dpnro NAME,TYPE | awk '$2 == "disk" {print $1}')
		log "Available installation disks"
		lsblk -dpno NAME,SIZE,MODEL,TYPE
		prompt_select DISK "Disk to erase" 1 "${disks[@]}"
	fi
	DISK=$(readlink -f -- "$DISK")
	if [[ -n ${SYSTEM_HOST_PROFILE:-} ]]; then
		HOST_PROFILE=$SYSTEM_HOST_PROFILE
	else
		for path in "$PROJECT_ROOT"/hosts/*.sh; do
			[[ -f $path && ! -L $path ]] || continue
			choice=${path##*/}
			profiles+=("${choice%.sh}")
			[[ ${choice%.sh} != zephyrus ]] || default_profile=${#profiles[@]}
		done
		prompt_select HOST_PROFILE "Host profile" "$default_profile" "${profiles[@]}"
	fi
	if [[ -n ${SYSTEM_DESKTOP:-} ]]; then
		DESKTOP=$SYSTEM_DESKTOP
	else
		prompt_select DESKTOP "Desktop" 1 plasma hyprland
	fi
	bootstrap_value HOSTNAME "Hostname" "${HOST_PROFILE//_/-}"
	bootstrap_value USERNAME "Login username" user
	bootstrap_value TIMEZONE "Timezone" UTC
	bootstrap_value LOCALE "Locale" en_US.UTF-8
	bootstrap_value KEYMAP "Console keymap" us
	exec 3<&-
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

	HOST_PROFILE=${HOST_PROFILE:-$HOSTNAME}
	DESKTOP=${DESKTOP:-plasma} # compatibility for pre-desktop installed configurations
	[[ $HOST_PROFILE =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || die "Invalid host profile: $HOST_PROFILE"
	validate_desktop
	export HOST_PROFILE DESKTOP

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
	local host="$PROJECT_ROOT/hosts/${HOST_PROFILE:?Missing host profile}.sh"
	[[ -f $host && ! -L $host ]] ||
		die "Host definition not found: $host"
}

load_bootstrap_config() {
	initialize_project
	prompt_bootstrap_config
	finalize_config
	require_host_definition
	installation_summary
}

load_rebuild_config() {
	initialize_project
	load_installed_config
	DESKTOP=${REBUILD_DESKTOP:-${DESKTOP:-plasma}}
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
		printf '# Generated installed-system configuration; contains no secrets.\n'
		printf 'DISK=%q\n' "$DISK"
		printf 'HOSTNAME=%q\n' "$HOSTNAME"
		printf 'HOST_PROFILE=%q\n' "$HOST_PROFILE"
		printf 'DESKTOP=%q\n' "$DESKTOP"
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
	unshare --mount --pid --fork --kill-child -- \
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
