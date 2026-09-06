head_resolve HimDek/Overview-Widget-for-Plasma metadata.json
archive_url="https://github.com/HimDek/Overview-Widget-for-Plasma/archive/$HEAD_COMMIT.tar.gz"
archive_hash=$(hash_url "$archive_url")
replace_line "$RECIPE_DIR/plasma6-applets-overview-widget.spec" '^%global commit ' "%global commit $HEAD_COMMIT"
replace_line "$RECIPE_DIR/plasma6-applets-overview-widget.spec" '^Version:[[:space:]]' "Version:        $HEAD_VERSION"
printf '%s  %s.tar.gz\n' "$archive_hash" "$HEAD_COMMIT" >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s (%s)\n' \
	plasma6-applets-overview-widget "$HEAD_VERSION" "${HEAD_COMMIT:0:7}"
