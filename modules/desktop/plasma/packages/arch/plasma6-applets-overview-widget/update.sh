head_resolve HimDek/Overview-Widget-for-Plasma metadata.json
archive_url="https://github.com/HimDek/Overview-Widget-for-Plasma/archive/$HEAD_COMMIT.tar.gz"
archive_hash=$(hash_url "$archive_url")
replace_line "$RECIPE_DIR/PKGBUILD" '^pkgver=' "pkgver=$HEAD_VERSION"
replace_line "$RECIPE_DIR/PKGBUILD" '^_commit=' "_commit=$HEAD_COMMIT"
replace_line "$RECIPE_DIR/PKGBUILD" '^sha256sums=' "sha256sums=('$archive_hash')"
printf 'Resolved %-42s %s (%s)\n' \
	plasma6-applets-overview-widget "$HEAD_VERSION" "${HEAD_COMMIT:0:7}"
