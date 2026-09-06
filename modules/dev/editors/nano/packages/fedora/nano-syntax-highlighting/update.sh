# shellcheck shell=bash
release_resolve galenguyer/nano-syntax-highlighting
archive_hash=$(hash_url "https://github.com/galenguyer/nano-syntax-highlighting/archive/refs/tags/$RELEASE_TAG.tar.gz")
replace_line "$RECIPE_DIR/nano-syntax-highlighting.spec" '^%global tag ' "%global tag $RELEASE_TAG"
replace_line "$RECIPE_DIR/nano-syntax-highlighting.spec" '^Version:[[:space:]]' "Version:        $RELEASE_VERSION"
printf '%s  %s.tar.gz\n' "$archive_hash" "$RELEASE_TAG" >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s\n' nano-syntax-highlighting "$RELEASE_VERSION"
