#!/usr/bin/env bash

# Arch owns its base package set, package operations, initial configuration,
# and mkinitcpio UKI generation.
distro_set_defaults() {
	KERNEL_PACKAGE=${KERNEL_PACKAGE:-linux}
	KERNEL_IMAGE=${KERNEL_IMAGE:-"/boot/vmlinuz-$KERNEL_PACKAGE"}
}

distro_require_bootstrap_commands() {
	require_commands pacstrap
}

distro_require_rebuild_commands() {
	require_commands pacstrap
}

distro_detect_microcode_package() {
	if [[ -n ${MICROCODE_PACKAGE:-} ]]; then
		printf '%s\n' "$MICROCODE_PACKAGE"
		return
	fi

	local vendor
	vendor=$(awk -F: '/vendor_id/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' /proc/cpuinfo)
	case $vendor in
	AuthenticAMD) printf 'amd-ucode\n' ;;
	GenuineIntel) printf 'intel-ucode\n' ;;
	*) warn "Unknown CPU vendor '$vendor'; no microcode package selected" ;;
	esac
}

distro_install_base_system() {
	local packages=(
		base "$KERNEL_PACKAGE" linux-firmware mkinitcpio btrfs-progs
		cryptsetup efibootmgr jq go-yq
	)
	local microcode_package
	microcode_package=$(distro_detect_microcode_package)
	if [[ -n $microcode_package ]]; then
		packages+=("$microcode_package")
		log "Microcode package: $microcode_package"
	fi

	log "Installing a clean Arch base"
	pacstrap -K "$TARGET_ROOT" "${packages[@]}"
}

distro_configure_base_system() {
	sed -i "s/^#${LOCALE//./\\.} UTF-8/${LOCALE} UTF-8/" "$TARGET_ROOT/etc/locale.gen"
	target_chroot locale-gen
}

distro_generate_uki() {
	local slot=$1
	local output=$2
	local luks_uuid letter installed_output
	luks_uuid=$(cryptsetup luksUUID "$CRYPT_PARTITION")
	letter=$(slot_letter "$slot")
	installed_output="/efi/EFI/Linux/$PROJECT_ID-$letter.efi"

	cat >"$TARGET_ROOT/etc/kernel/cmdline" <<EOF
rd.luks.name=$luks_uuid=$CRYPT_NAME root=/dev/mapper/$CRYPT_NAME rootflags=subvol=$slot rw
EOF

	sed -i \
		-e 's/^MODULES=.*/MODULES=(btrfs)/' \
		-e 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' \
		"$TARGET_ROOT/etc/mkinitcpio.conf"

	cat >"$TARGET_ROOT/etc/mkinitcpio.d/$PROJECT_ID.preset" <<EOF
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="$KERNEL_IMAGE"
PRESETS=('default')
default_uki="$output"
EOF

	target_chroot mkinitcpio -p "$PROJECT_ID"

	# Initial generation targets an atomic temporary path. Future native kernel
	# transactions must write the active slot's permanent UKI, so retain that
	# destination in the installed preset and explicitly rebuild it after the
	# stock kernel hook has copied a new /boot/vmlinuz-*.
	sed -i \
		"s|^default_uki=.*|default_uki=\"$installed_output\"|" \
		"$TARGET_ROOT/etc/mkinitcpio.d/$PROJECT_ID.preset"
	mkdir -p "$TARGET_ROOT/etc/pacman.d/hooks"
	cat >"$TARGET_ROOT/etc/pacman.d/hooks/95-$PROJECT_ID-uki.hook" <<EOF
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = $KERNEL_PACKAGE

[Action]
Description = Refreshing the active $PROJECT_ID UKI...
When = PostTransaction
Exec = /usr/bin/mkinitcpio -p $PROJECT_ID
EOF
}

pkg_native_install() {
	pacman -S --needed --noconfirm -- "$@"
}

pkg_native_is_installed() {
	pacman -Qq -- "$1" >/dev/null 2>&1
}

pkg_native_remove() {
	pacman -Rns --noconfirm -- "$@"
}
