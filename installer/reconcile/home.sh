#!/usr/bin/env bash
set -Eeuo pipefail

warn() {
	printf 'warning: %s\n' "$*" >&2
}

log_change() {
	printf '  %s\n' "$*"
}

ensure_user_directory() {
	local directory=$1
	[[ -d $directory && ! -L $directory ]] && return
	local parent
	parent=$(dirname -- "$directory")
	ensure_user_directory "$parent"
	mkdir -- "$directory"
	chown "$OWNER" "$directory"
}

safe_destination() {
	local relative=$1
	[[ -n $relative && $relative != /* && $relative != .. && $relative != ../* && $relative != */../* ]] || {
		warn "unsafe skeleton path: $relative"
		return 1
	}

	local parent
	parent=$(realpath -m "$HOME_DIR/$(dirname -- "$relative")")
	[[ $parent == "$HOME_DIR" || $parent == "$HOME_DIR"/* ]] || {
		warn "skeleton path escapes home through a symlink: $relative"
		return 1
	}
}

infer_strategy() {
	case ${1,,} in
	*.json) printf 'json\n' ;;
	*.yaml | *.yml) printf 'yaml\n' ;;
	*.toml) printf 'toml\n' ;;
	*.ini) printf 'ini\n' ;;
	*) printf 'replace\n' ;;
	esac
}

read_policy() {
	local relative=$1
	local policy_file=$2
	local strategy delete_mode
	strategy=$(infer_strategy "$relative")
	delete_mode=$DEFAULT_DELETE_MODE

	if [[ -f $policy_file ]]; then
		local override
		override=$(awk -F '\t' -v path="$relative" '$1 == path { print $2 "\t" $3 }' "$policy_file" | tail -n 1)
		if [[ -n $override ]]; then
			IFS=$'\t' read -r strategy delete_mode <<<"$override"
			[[ $strategy == auto ]] && strategy=$(infer_strategy "$relative")
		fi
	fi
	printf '%s\t%s\n' "$strategy" "$delete_mode"
}

backup_path() {
	local destination=$1
	local relative=$2
	[[ -e $destination || -L $destination ]] || return 0

	local backup="$BACKUP_ROOT/$relative"
	ensure_user_directory "$(dirname -- "$backup")"
	rm -rf -- "$backup"
	cp -a -- "$destination" "$backup"
	chown -hR "$OWNER" "$backup"
	log_change "backed up $relative"
}

remove_path() {
	local destination=$1
	if [[ -d $destination && ! -L $destination ]]; then
		rm -rf -- "$destination"
	else
		rm -f -- "$destination"
	fi
}

same_file() {
	local left=$1
	local right=$2
	if [[ -L $left || -L $right ]]; then
		[[ -L $left && -L $right && $(readlink -- "$left") == "$(readlink -- "$right")" ]]
	else
		[[ -f $left && -f $right ]] && cmp -s -- "$left" "$right"
	fi
}

install_file() {
	local source=$1
	local destination=$2
	local relative=$3

	if same_file "$source" "$destination"; then
		return 0
	fi
	if [[ -e $destination || -L $destination ]]; then
		backup_path "$destination" "$relative"
		remove_path "$destination"
	fi
	ensure_user_directory "$(dirname -- "$destination")"

	local temporary="$destination.${PROJECT_ID}-tmp"
	rm -rf -- "$temporary"
	if [[ -L $source ]]; then
		ln -s -- "$(readlink -- "$source")" "$temporary"
		chown -h "$OWNER" "$temporary"
	else
		install -o "$USER_ID" -g "$GROUP_ID" -m "$(stat -c %a "$source")" "$source" "$temporary"
	fi
	mv -Tf -- "$temporary" "$destination"
	log_change "installed $relative"
}

to_json() {
	local strategy=$1
	local source=$2
	local output=$3
	case $strategy in
	json) jq '.' "$source" >"$output" ;;
	yaml) yq --input-format yaml --output-format json '.' "$source" >"$output" ;;
	toml) yq --input-format toml --output-format json '.' "$source" >"$output" ;;
	*) return 1 ;;
	esac
}

from_json() {
	local strategy=$1
	local source=$2
	local output=$3
	case $strategy in
	json) jq '.' "$source" >"$output" ;;
	yaml) yq --input-format json --output-format yaml '.' "$source" >"$output" ;;
	toml) yq --input-format json --output-format toml '.' "$source" >"$output" ;;
	*) return 1 ;;
	esac
}

require_strategy_tool() {
	local strategy=$1
	local command=$strategy
	case $strategy in
	json) command=jq ;;
	yaml | toml) command=yq ;;
	ini) command=crudini ;;
	esac
	command -v "$command" >/dev/null 2>&1
}

merge_structured() {
	local strategy=$1
	local previous=$2
	local desired=$3
	local actual=$4
	local output=$5
	local work
	work=$(mktemp -d)

	if [[ $strategy == ini ]]; then
		if ! require_strategy_tool ini; then
			rm -rf "$work"
			return 1
		fi
		cp -- "$actual" "$output"
		crudini --merge "$output" <"$desired"
		rm -rf "$work"
		return 0
	fi

	if ! require_strategy_tool "$strategy"; then
		rm -rf "$work"
		return 1
	fi
	if [[ -f $previous ]]; then
		to_json "$strategy" "$previous" "$work/old.json" || {
			rm -rf "$work"
			return 1
		}
	else
		printf '{}\n' >"$work/old.json"
	fi
	to_json "$strategy" "$desired" "$work/new.json" || {
		rm -rf "$work"
		return 1
	}
	to_json "$strategy" "$actual" "$work/actual.json" || {
		rm -rf "$work"
		return 1
	}

	jq -n \
		--slurpfile old "$work/old.json" \
		--slurpfile new "$work/new.json" \
		--slurpfile actual "$work/actual.json" \
		-f "/run/$PROJECT_ID/installer/reconcile/three-way.jq" \
		>"$work/result.json" || {
		rm -rf "$work"
		return 1
	}
	from_json "$strategy" "$work/result.json" "$output" || {
		rm -rf "$work"
		return 1
	}
	rm -rf "$work"
}

prune_structured() {
	local strategy=$1
	local previous=$2
	local actual=$3
	local output=$4
	local work
	work=$(mktemp -d)

	[[ $strategy != ini ]] || {
		rm -rf "$work"
		return 1
	}
	require_strategy_tool "$strategy" || {
		rm -rf "$work"
		return 1
	}
	to_json "$strategy" "$previous" "$work/old.json" || {
		rm -rf "$work"
		return 1
	}
	to_json "$strategy" "$actual" "$work/actual.json" || {
		rm -rf "$work"
		return 1
	}
	printf '{}\n' >"$work/new.json"

	jq -n \
		--slurpfile old "$work/old.json" \
		--slurpfile new "$work/new.json" \
		--slurpfile actual "$work/actual.json" \
		-f "/run/$PROJECT_ID/installer/reconcile/three-way.jq" \
		>"$work/result.json" || {
		rm -rf "$work"
		return 1
	}

	if jq -e 'type == "object" and length == 0' "$work/result.json" >/dev/null; then
		: >"$output"
	else
		from_json "$strategy" "$work/result.json" "$output" || {
			rm -rf "$work"
			return 1
		}
	fi
	rm -rf "$work"
}

reconcile_present() {
	local relative=$1
	local source="$NEW_SKEL/$relative"
	local previous="$OLD_SKEL/$relative"
	local destination="$HOME_DIR/$relative"
	local strategy delete_mode
	IFS=$'\t' read -r strategy delete_mode < <(read_policy "$relative" "$NEW_POLICIES")

	case $strategy in
	keep)
		[[ -e $destination || -L $destination ]] || install_file "$source" "$destination" "$relative"
		;;
	replace)
		install_file "$source" "$destination" "$relative"
		;;
	json | yaml | toml | ini)
		if [[ ! -f $destination || -L $destination || -L $source ]]; then
			install_file "$source" "$destination" "$relative"
			return
		fi
		local merged
		merged=$(mktemp)
		if merge_structured "$strategy" "$previous" "$source" "$destination" "$merged"; then
			chmod --reference="$destination" "$merged"
			install_file "$merged" "$destination" "$relative"
		else
			warn "could not merge $relative as $strategy; replacing it"
			install_file "$source" "$destination" "$relative"
		fi
		rm -f "$merged"
		;;
	*)
		warn "unknown strategy '$strategy' for $relative; replacing it"
		install_file "$source" "$destination" "$relative"
		;;
	esac
}

reconcile_removed() {
	local relative=$1
	local previous="$OLD_SKEL/$relative"
	local destination="$HOME_DIR/$relative"
	[[ -e $destination || -L $destination ]] || return 0

	local strategy delete_mode
	IFS=$'\t' read -r strategy delete_mode < <(read_policy "$relative" "$OLD_POLICIES")
	case $delete_mode in
	never) return ;;
	backup)
		backup_path "$destination" "$relative"
		remove_path "$destination"
		log_change "removed $relative"
		return
		;;
	force)
		remove_path "$destination"
		log_change "removed $relative"
		return
		;;
	unchanged) ;;
	*)
		warn "unknown deletion mode '$delete_mode' for $relative; preserving it"
		return
		;;
	esac

	if [[ $strategy == json || $strategy == yaml || $strategy == toml ]] && [[ -f $destination && ! -L $destination ]]; then
		local pruned
		pruned=$(mktemp)
		if prune_structured "$strategy" "$previous" "$destination" "$pruned"; then
			if [[ ! -s $pruned ]]; then
				remove_path "$destination"
				log_change "removed $relative"
			else
				chmod --reference="$destination" "$pruned"
				install_file "$pruned" "$destination" "$relative"
			fi
			rm -f "$pruned"
			return
		fi
		rm -f "$pruned"
	fi

	if same_file "$previous" "$destination"; then
		remove_path "$destination"
		log_change "removed unchanged $relative"
	else
		warn "preserving user-modified path removed from skeleton: $relative"
	fi
}

main() {
	OLD_SKEL=${1:?old skeleton is required}
	NEW_SKEL=${2:?new skeleton is required}
	HOME_DIR=${3:?home directory is required}
	OLD_POLICIES=${4:-/nonexistent}
	NEW_POLICIES=${5:-/nonexistent}
	USER_ID=${6:?user ID is required}
	GROUP_ID=${7:?group ID is required}
	DEFAULT_DELETE_MODE=${HOME_DELETE_MODE:-unchanged}
	OWNER="$USER_ID:$GROUP_ID"
	: "${PROJECT_ID:?PROJECT_ID is required}"
	BACKUP_ROOT="$HOME_DIR/.local/state/$PROJECT_ID/backups/$(date -u +%Y%m%dT%H%M%SZ)"

	ensure_user_directory "$HOME_DIR"

	while IFS= read -r -d '' directory; do
		local relative=${directory#"$NEW_SKEL"/}
		[[ $directory == "$NEW_SKEL" ]] && continue
		safe_destination "$relative" || continue
		local destination="$HOME_DIR/$relative"
		if [[ -L $destination || (-e $destination && ! -d $destination) ]]; then
			backup_path "$destination" "$relative"
			remove_path "$destination"
		fi
		if [[ ! -d $destination ]]; then
			ensure_user_directory "$destination"
		fi
	done < <(find "$NEW_SKEL" -type d -print0 | sort -z)

	while IFS= read -r -d '' source; do
		local relative=${source#"$NEW_SKEL"/}
		safe_destination "$relative" || continue
		reconcile_present "$relative"
	done < <(find "$NEW_SKEL" \( -type f -o -type l \) -print0 | sort -z)

	while IFS= read -r -d '' previous; do
		local relative=${previous#"$OLD_SKEL"/}
		[[ -e "$NEW_SKEL/$relative" || -L "$NEW_SKEL/$relative" ]] && continue
		safe_destination "$relative" || continue
		reconcile_removed "$relative"
	done < <(find "$OLD_SKEL" \( -type f -o -type l \) -print0 | sort -z)
}

main "$@"
