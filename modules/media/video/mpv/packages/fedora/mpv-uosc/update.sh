release_resolve tomasklaen/uosc
base=https://github.com/tomasklaen/uosc
archive_hash=$(hash_url "$base/releases/download/$RELEASE_TAG/uosc.zip")
config_hash=$(hash_url "$base/releases/download/$RELEASE_TAG/uosc.conf")
license_hash=$(hash_url "$base/raw/$RELEASE_TAG/LICENSE.LGPL")
replace_line "$RECIPE_DIR/mpv-uosc.spec" '^%global tag ' "%global tag $RELEASE_TAG"
replace_line "$RECIPE_DIR/mpv-uosc.spec" '^Version:[[:space:]]' "Version:        $RELEASE_VERSION"
{
	printf '%s  uosc.zip\n' "$archive_hash"
	printf '%s  uosc.conf\n' "$config_hash"
	printf '%s  LICENSE.LGPL\n' "$license_hash"
} >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s\n' mpv-uosc "$RELEASE_VERSION"
