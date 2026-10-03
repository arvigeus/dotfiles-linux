# shellcheck shell=bash
release_commit_resolve christoph-heinrich/sosc
archive_hash=$(hash_url "https://github.com/christoph-heinrich/sosc/archive/$HEAD_COMMIT.tar.gz")
replace_line "$RECIPE_DIR/PKGBUILD" '^pkgver=' "pkgver=$RELEASE_VERSION"
replace_line "$RECIPE_DIR/PKGBUILD" '^_commit=' "_commit=$HEAD_COMMIT"
replace_line "$RECIPE_DIR/PKGBUILD" '^sha256sums=' "sha256sums=('$archive_hash')"
printf 'Resolved %-42s %s (%s)\n' mpv-sosc "$RELEASE_VERSION" "${HEAD_COMMIT:0:7}"
