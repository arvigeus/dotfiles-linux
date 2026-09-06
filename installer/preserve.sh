#!/usr/bin/env bash

preserve_active_state() {
	local requests="$TARGET_ROOT/run/$PROJECT_ID-preserve-requests"

	# A clean-root rebuild is still the same installed machine. Keep its systemd
	# identity as an installer lifecycle invariant rather than a selectable
	# module. Bootstrap does not call this function and therefore still creates
	# a new identity for a genuinely new installation.
	log "Preserving machine state"
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
	done < <(
		{
			printf '%s\n' /etc/machine-id
			if [[ -s $requests ]]; then
				cat -- "$requests"
			fi
		} | sort -u
	)
	rm -f -- "$requests"
}

initialize_machine_id() {
	systemd-machine-id-setup --root="$TARGET_ROOT"
}
