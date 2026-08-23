#!/usr/bin/env bash

preserve_active_state() {
	local requests="$TARGET_ROOT/run/$PROJECT_ID-preserve-requests"
	[[ -s $requests ]] || {
		rm -f -- "$requests"
		return 0
	}

	log "Preserving module-requested machine state"
	local pattern source relative destination
	while IFS= read -r pattern || [[ -n $pattern ]]; do
		[[ $pattern == /* && $pattern != / ]] ||
			die "Invalid module preserve request: $pattern"

		while IFS= read -r source; do
			[[ -e $source || -L $source ]] || continue
			relative=${source#/}
			destination="$TARGET_ROOT/$relative"
			mkdir -p "$(dirname -- "$destination")"
			rm -rf -- "$destination"
			cp -a -- "$source" "$destination"
		done < <(compgen -G "$pattern" || true)
	done < <(sort -u -- "$requests")
	rm -f -- "$requests"
}

initialize_machine_id() {
	systemd-machine-id-setup --root="$TARGET_ROOT"
}
