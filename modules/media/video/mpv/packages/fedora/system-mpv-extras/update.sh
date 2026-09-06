# shellcheck shell=bash
release_resolve iwalton3/default-shader-pack
shader_tag=$RELEASE_TAG
shader_version=$RELEASE_VERSION
shader_hash=$(hash_url "https://github.com/iwalton3/default-shader-pack/archive/refs/tags/$shader_tag.tar.gz")

head_commit_resolve po5/thumbfast
thumbfast_commit=$HEAD_COMMIT
thumbfast_date=$HEAD_DATE
thumbfast_hash=$(hash_url "https://github.com/po5/thumbfast/archive/$thumbfast_commit.tar.gz")

head_commit_resolve christoph-heinrich/sosc
sosc_commit=$HEAD_COMMIT
sosc_hash=$(hash_url "https://github.com/christoph-heinrich/sosc/archive/$sosc_commit.tar.gz")

version="$shader_version.$thumbfast_date"
spec="$RECIPE_DIR/system-mpv-extras.spec"
replace_line "$spec" '^%global shader_tag ' "%global shader_tag $shader_tag"
replace_line "$spec" '^%global thumbfast_commit ' "%global thumbfast_commit $thumbfast_commit"
replace_line "$spec" '^%global sosc_commit ' "%global sosc_commit $sosc_commit"
replace_line "$spec" '^Version:[[:space:]]' "Version:        $version"
{
	printf '%s  %s.tar.gz\n' "$shader_hash" "$shader_tag"
	printf '%s  %s.tar.gz\n' "$thumbfast_hash" "$thumbfast_commit"
	printf '%s  %s.tar.gz\n' "$sosc_hash" "$sosc_commit"
} >"$RECIPE_DIR/sources.sha256"
printf 'Resolved %-42s %s\n' system-mpv-extras "$version"
