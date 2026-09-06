# shellcheck shell=bash
release_resolve arkenfox/user.js
archive_hash=$(hash_url \
	"https://github.com/arkenfox/user.js/archive/refs/tags/$RELEASE_TAG.tar.gz" \
	"$RELEASE_TAG.tar.gz")
replace_line "$RECIPE_DIR/PKGBUILD" '^pkgver=' "pkgver=$RELEASE_VERSION"
replace_line "$RECIPE_DIR/PKGBUILD" '^sha256sums=' "sha256sums=('$archive_hash')"
printf 'Resolved %-42s %s\n' arkenfox-user.js "$RELEASE_VERSION"
