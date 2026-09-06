# shellcheck shell=bash
page=$(curl_stdout https://gravitymark.tellusim.com/)
installer_url=$(
	grep -Eom1 \
		'https?://tellusim[.]com/download/GravityMark_[0-9.]+[.]run|/download/GravityMark_[0-9.]+[.]run|download/GravityMark_[0-9.]+[.]run' \
		<<<"$page" |
		sed 's|^/download|https://tellusim.com/download|; s|^download|https://tellusim.com/download|'
)
[[ $installer_url =~ ^https://tellusim[.]com/download/GravityMark_([0-9.]+)[.]run$ ]] || {
	printf 'Could not resolve the latest GravityMark x86-64 installer\n' >&2
	exit 1
}
version=${BASH_REMATCH[1]}
installer_name="GravityMark_$version.run"
installer_hash=$(hash_url "$installer_url" "$installer_name")
replace_line "$RECIPE_DIR/gravitymark.spec" '^Version:[[:space:]]' "Version:        $version"
printf '%s  GravityMark_%s.run\n' "$installer_hash" "$version" >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s\n' gravitymark "$version"
