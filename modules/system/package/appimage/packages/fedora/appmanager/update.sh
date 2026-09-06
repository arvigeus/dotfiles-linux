release_resolve kem-a/AppManager
archive_url="https://github.com/kem-a/AppManager/archive/refs/tags/$RELEASE_TAG.tar.gz"
archive_hash=$(hash_url "$archive_url")
replace_line "$RECIPE_DIR/appmanager.spec" '^%global tag ' "%global tag $RELEASE_TAG"
replace_line "$RECIPE_DIR/appmanager.spec" '^Version:[[:space:]]' "Version:        $RELEASE_VERSION"
printf '%s  %s.tar.gz\n' "$archive_hash" "$RELEASE_TAG" >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s\n' appmanager "$RELEASE_VERSION"
