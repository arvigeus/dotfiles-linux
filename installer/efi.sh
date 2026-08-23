#!/usr/bin/env bash

label_for_slot() {
	case $1 in
	"$ROOT_A") printf '%s\n' "$EFI_LABEL_A" ;;
	"$ROOT_B") printf '%s\n' "$EFI_LABEL_B" ;;
	*) die "Unknown slot: $1" ;;
	esac
}

boot_number_for_label() {
	local label=$1
	efibootmgr | awk -v wanted="$label" '
        /^Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/ {
            number = substr($0, 5, 4)
            rest = substr($0, 9)
            sub(/^[*[:space:]]+/, "", rest)
            if (index(rest, wanted) == 1) {
                print toupper(number)
                exit
            }
        }
    '
}

ensure_boot_entry() {
	local slot=$1
	local label letter number
	label=$(label_for_slot "$slot")
	letter=$(slot_letter "$slot")
	number=$(boot_number_for_label "$label")

	if [[ -z $number ]]; then
		log "Creating UEFI entry: $label" >&2
		efibootmgr \
			--create \
			--disk "$DISK" \
			--part "$ESP_PARTITION_NUMBER" \
			--label "$label" \
			--loader "\\EFI\\Linux\\${PROJECT_ID}-${letter}.efi" \
			>/dev/null
		number=$(boot_number_for_label "$label")
	fi

	[[ -n $number ]] || die "Could not create or find UEFI entry: $label"
	printf '%s\n' "$number"
}

activate_slot() {
	local target_slot=$1
	local active_slot=${2:-}
	local target_number active_number current_order entry order=()

	target_number=$(ensure_boot_entry "$target_slot")
	if [[ -n $active_slot ]]; then
		active_number=$(ensure_boot_entry "$active_slot")
	fi

	order+=("$target_number")
	if [[ -n ${active_number:-} && $active_number != "$target_number" ]]; then
		order+=("$active_number")
	fi

	current_order=$(efibootmgr | awk -F': ' '/^BootOrder:/ { print $2; exit }')
	IFS=',' read -r -a existing_entries <<<"$current_order"
	for entry in "${existing_entries[@]}"; do
		[[ -n $entry && $entry != "$target_number" && $entry != "${active_number:-}" ]] && order+=("$entry")
	done

	local joined
	joined=$(
		IFS=,
		printf '%s' "${order[*]}"
	)
	log "Setting UEFI boot order to $joined"
	efibootmgr --bootorder "$joined"
}
