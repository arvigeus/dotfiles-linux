# shellcheck shell=bash
release_resolve arkenfox/user.js
archive_hash=$(hash_url \
	"https://github.com/arkenfox/user.js/archive/refs/tags/$RELEASE_TAG.tar.gz" \
	"$RELEASE_TAG.tar.gz")
replace_line "$RECIPE_DIR/arkenfox-user.js.spec" '^%global tag ' "%global tag $RELEASE_TAG"
replace_line "$RECIPE_DIR/arkenfox-user.js.spec" '^Version:[[:space:]]' "Version:        $RELEASE_VERSION"
printf '%s  %s.tar.gz\n' "$archive_hash" "$RELEASE_TAG" >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s\n' arkenfox-user.js "$RELEASE_VERSION"
