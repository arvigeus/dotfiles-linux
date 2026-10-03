repository=Blacksuan19/plasma-wallpaper-wallhaven-reborn
release_commit_resolve "$repository"
archive_url="https://github.com/$repository/archive/$HEAD_COMMIT.tar.gz"
archive_hash=$(hash_url "$archive_url")
replace_line "$RECIPE_DIR/plasma6-applets-wallhaven-reborn.spec" '^%global commit ' "%global commit $HEAD_COMMIT"
replace_line "$RECIPE_DIR/plasma6-applets-wallhaven-reborn.spec" '^Version:[[:space:]]' "Version:        $RELEASE_VERSION"
printf '%s  %s.tar.gz\n' "$archive_hash" "$HEAD_COMMIT" >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s (%s)\n' \
	plasma6-applets-wallhaven-reborn "$RELEASE_VERSION" "${HEAD_COMMIT:0:7}"
