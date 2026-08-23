#!/usr/bin/env bash
## Shared helpers for browser modules (firefox, chromium, zen).
##
## Browser modules load their local common.jsonc and pass it to helpers:
##   gecko_profiles_ini             — emits profiles.ini for a Firefox-like browser
##   firefox_install_search_engines <config-json> <profile>
##   firefox_install_extensions <config-json> <dest>
##   chromium_install_extensions <config-json> [browser]

# A deterministic profile so Firefox-based browsers don't auto-create a random
# "*.default-release" one (which would never see our user.js).
gecko_profiles_ini() {
	cat <<'EOF'
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=default
IsRelative=1
Path=default
Default=1
EOF
}

gecko_generate_userjs() {
	local -n prefs="$1"

	while read -r key; do
		local value="${prefs[$key]}"

		if [[ "$value" =~ ^(true|false)$ ]]; then
			printf 'user_pref("%s", %s);\n' "$key" "$value"

		elif [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
			printf 'user_pref("%s", %s);\n' "$key" "$value"

		else
			value=${value//\\/\\\\}
			value=${value//\"/\\\"}

			printf 'user_pref("%s", "%s");\n' "$key" "$value"
		fi
	done < <(printf '%s\n' "${!prefs[@]}" | sort)
}

# Mozilla mozLz4 format: "mozLz40\0" magic + 4-byte LE size + LZ4 block.
# LZ4 allows an all-literal sequence, so we emit uncompressed — pure bash,
# no python-lz4.
_write_mozlz4() {
	local input=$1 size rem
	size=$(stat -c%s "$input")

	printf 'mozLz40\0'

	printf '%b' \
		"\\x$(printf '%02x' "$((size & 0xff))")" \
		"\\x$(printf '%02x' "$(((size >> 8) & 0xff))")" \
		"\\x$(printf '%02x' "$(((size >> 16) & 0xff))")" \
		"\\x$(printf '%02x' "$(((size >> 24) & 0xff))")"

	# LZ4 token: high nibble = literal length (15 = "read extension bytes"),
	# low nibble = match length (unused — last sequence has no match).
	# Below: `size * 16` shifts size into the high nibble (equivalent to size << 4).
	if ((size < 15)); then
		printf '%b' "\\x$(printf '%02x' "$((size * 16))")"
	else
		printf '\xf0'
		rem=$((size - 15))
		while ((rem >= 255)); do
			printf '\xff'
			rem=$((rem - 255))
		done
		printf '%b' "\\x$(printf '%02x' "$rem")"
	fi

	cat "$input"
}

# ── Extensions ───────────────────────────────────────────────────────────────

_firefox_install_extension() (
	set -Eeuo pipefail
	local url=$1 dest_dir=$2 id_fallback=${3:-}
	local filename tmpdir manifest extension_id

	filename=$(basename "$url")
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	curl --fail --silent --show-error --location \
		--output "$tmpdir/$filename" "$url"
	unzip -q "$tmpdir/$filename" -d "$tmpdir/unpacked"

	manifest="$tmpdir/unpacked/manifest.json"
	if [[ -f $manifest ]]; then
		extension_id=$(jq -r '.browser_specific_settings.gecko.id // .applications.gecko.id // empty' "$manifest")
	fi
	[[ -n ${extension_id:-} ]] || extension_id=$id_fallback
	[[ -n $extension_id ]] || {
		printf 'No extension ID in %s\n' "$filename" >&2
		return 1
	}
	install -m 0644 "$tmpdir/$filename" "$dest_dir/$extension_id.xpi"
)

firefox_install_extensions() {
	local browsers_config=$1 dest_dir=$2
	mkdir -p "$dest_dir"

	while IFS=$'\t' read -r url id_fallback; do
		[[ -z "$url" ]] && continue
		_firefox_install_extension "$url" "$dest_dir" "$id_fallback"
	done < <(jq -r '
		.extensions[]
		| select(.firefox)
		| [.firefox, (.firefox_id_fallback // "")]
		| @tsv
	' <<<"$browsers_config")
}

chromium_install_extensions() {
	local browsers_config=$1 url extension_id
	local entries=()

	while IFS= read -r url; do
		[[ -n $url ]] || continue
		if [[ $url =~ /detail/[^/]+/([a-zA-Z]+)/?$ ]]; then
			extension_id=${BASH_REMATCH[1]}
		else
			printf 'Could not extract Chromium extension ID from %s\n' "$url" >&2
			return 1
		fi
		entries+=("$extension_id;https://clients2.google.com/service/update2/crx")
	done < <(jq -r '.extensions[].chromium // empty' <<<"$browsers_config")

	printf '%s\n' "${entries[@]}" |
		jq -R -s '{ExtensionInstallForcelist: (split("\n") | map(select(length > 0)))}' |
		file_write /etc/chromium/policies/managed/ported-extensions.json
}

# ── Search engines ───────────────────────────────────────────────────────────

_firefox_build_search_json() {
	local entries=() order=1

	# jq: --arg for JSON escaping; UUIDs derived from name (UUIDv5, @url namespace).
	while IFS=$'\t' read -r id name; do
		entries+=("$(jq -n \
			--arg id "$id" --arg name "$name" --argjson order "$order" \
			'{ id: $id, _name: $name, _isAppProvided: true,
			   _metaData: { order: $order } }')")
		((order++))
	done < <(jq -r '.app_engines[] | [.id, .name] | @tsv' <<<"$_search_engines")

	while IFS=$'\t' read -r name icon template alias; do
		entries+=("$(jq -n \
			--arg id "$(uuidgen --sha1 --namespace @url --name "$name")" \
			--arg name "$name" --arg icon "$icon" \
			--arg template "$template" --arg alias "$alias" \
			--argjson order "$order" \
			'{ id: $id, _name: $name, _loadPath: "[user]",
			   _iconMapObj: { "16": $icon },
			   _metaData: { order: $order },
			   _urls: [{ params: [], rels: [], template: $template }],
			   _orderHint: null, _telemetryId: null, _filePath: null,
			   _definedAliases: [$alias] }')")
		((order++))
	done < <(jq -r '.user_engines[] | [.name, .icon, .template, .alias] | @tsv' <<<"$_search_engines")

	printf '%s\n' "${entries[@]}" | jq -s --arg distro "$DISTRO" '
		{ version: 12,
		  engines: .,
		  metaData: {
		      useSavedOrder: true,
		      locale: "en-US",
		      region: "VN",
		      channel: "release",
		      experiment: "",
		      distroID: ({"arch": "archlinux"}[$distro] // $distro),
		      appDefaultEngineId: "google"
		  } }'
}

firefox_install_search_engines() (
	set -Eeuo pipefail
	local browsers_config=$1 profile_dir=$2
	local search_src _search_engines

	# Flatten distro_engines[$DISTRO] + common_engines into a user_engines list.
	_search_engines=$(jq --arg distro "$DISTRO" '
		.search_engines | { app_engines,
		  user_engines: ((.distro_engines[$distro] // []) + .common_engines) }
	' <<<"$browsers_config")

	search_src=$(mktemp)
	trap 'rm -f -- "$search_src"' EXIT
	_firefox_build_search_json >"$search_src"

	mkdir -p "$profile_dir"
	_write_mozlz4 "$search_src" | file_write "$profile_dir/search.json.mozlz4"
)
