#!/usr/bin/env bash

# Fedora owns its installroot package set, RPM operations, SELinux labelling,
# and dracut UKI generation.
distro_set_defaults() {
	KERNEL_PACKAGE=${KERNEL_PACKAGE:-kernel}
}

distro_require_bootstrap_commands() {
	require_commands dnf find setfiles sort tail
}

distro_require_rebuild_commands() {
	require_commands dnf find setfiles sort tail
}

distro_detect_microcode_package() {
	local vendor
	vendor=$(awk -F: '/vendor_id/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' /proc/cpuinfo)
	case $vendor in
	AuthenticAMD) printf 'amd-ucode-firmware\n' ;;
	GenuineIntel) printf 'microcode_ctl\n' ;;
	*) warn "Unknown CPU vendor '$vendor'; no microcode package selected" ;;
	esac
}

distro_install_base_system() {
	local locale_language=${LOCALE%%[_@.]*}
	locale_language=${locale_language,,}
	local packages=(
		basesystem bash coreutils diffutils filesystem findutils gawk grep sed tar gzip
		util-linux passwd shadow-utils setup fedora-release fedora-repos
		dnf rpm systemd systemd-udev kbd "glibc-langpack-$locale_language"
		kernel kernel-core kernel-modules kernel-modules-core linux-firmware
		dracut dracut-config-generic systemd-boot-unsigned systemd-ukify
		btrfs-progs ca-certificates cryptsetup curl efibootmgr NetworkManager iproute iputils
		jq yq sudo selinux-policy-targeted policycoreutils
	)
	local microcode_package
	microcode_package=$(distro_detect_microcode_package)
	[[ -z $microcode_package ]] || packages+=("$microcode_package")

	log "Installing a clean Fedora $DISTRO_VERSION_ID base"
	prepare_target_chroot
	dnf -y \
		--installroot="$TARGET_ROOT" \
		--releasever="$DISTRO_VERSION_ID" \
		--use-host-config \
		--setopt=install_weak_deps=False \
		install "${packages[@]}"
}

distro_configure_base_system() {
	# Fedora presets normally enable NetworkManager; make the minimal backend's
	# networking contract explicit even when installroot scriptlets skip presets.
	target_chroot systemctl enable NetworkManager.service
}

fedora_kernel_version() {
	local version
	version=$(find "$TARGET_ROOT/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d \
		-printf '%f\n' | sort -V | tail -n 1)
	[[ -n $version ]] || die "Could not find an installed Fedora kernel"
	printf '%s\n' "$version"
}

distro_generate_uki() {
	local slot=$1
	local output=$2
	local luks_uuid kernel_version kernel_image cmdline
	luks_uuid=$(cryptsetup luksUUID "$CRYPT_PARTITION")
	kernel_version=$(fedora_kernel_version)
	kernel_image="/usr/lib/modules/$kernel_version/vmlinuz"
	[[ -f $TARGET_ROOT$kernel_image ]] || kernel_image="/boot/vmlinuz-$kernel_version"
	[[ -f $TARGET_ROOT$kernel_image ]] || die "Fedora kernel image not found for $kernel_version"

	cmdline="rd.luks.name=$luks_uuid=$CRYPT_NAME root=/dev/mapper/$CRYPT_NAME rootfstype=btrfs rootflags=subvol=$slot rw selinux=1 enforcing=1"
	printf '%s\n' "$cmdline" >"$TARGET_ROOT/etc/kernel/cmdline"
	install -Dm755 \
		"$PROJECT_ROOT/installer/distros/fedora/system-refresh-uki" \
		"$TARGET_ROOT/usr/local/libexec/system-refresh-uki"
	install -Dm755 \
		"$PROJECT_ROOT/installer/distros/fedora/95-system-uki.install" \
		"$TARGET_ROOT/etc/kernel/install.d/95-system-uki.install"

	target_chroot dracut \
		--force \
		--no-hostonly \
		--add "crypt btrfs systemd systemd-initrd i18n" \
		--uefi \
		--ukify \
		--kernel-image "$kernel_image" \
		--kernel-cmdline "$cmdline" \
		"$output" \
		"$kernel_version"
}

distro_finalize_security() {
	local contexts="$TARGET_ROOT/etc/selinux/targeted/contexts/files/file_contexts"
	[[ -f $contexts ]] || die "Fedora SELinux file contexts are missing from the candidate"

	log "Applying Fedora SELinux labels to the candidate root and persistent home"
	setfiles -F -r "$TARGET_ROOT" \
		-e "$TARGET_ROOT/dev" \
		-e "$TARGET_ROOT/proc" \
		-e "$TARGET_ROOT/sys" \
		-e "$TARGET_ROOT/run" \
		-e "$TARGET_ROOT/efi" \
		"$contexts" "$TARGET_ROOT"
	rm -f "$TARGET_ROOT/.autorelabel"
}
