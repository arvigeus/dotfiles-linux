#!/usr/bin/env bash

generate_uki() {
	local slot=$1
	local letter temporary final
	letter=$(slot_letter "$slot")
	temporary="/efi/EFI/Linux/.${PROJECT_ID}-${letter}.tmp.efi"
	final="$TARGET_ROOT/efi/EFI/Linux/${PROJECT_ID}-${letter}.efi"

	mkdir -p "$TARGET_ROOT/efi/EFI/Linux" "$TARGET_ROOT/etc/kernel"
	log "Generating $DISTRO UKI for $slot"
	distro_generate_uki "$slot" "$temporary"
	mv -f "$TARGET_ROOT$temporary" "$final"
	sync -f "$final"
}
