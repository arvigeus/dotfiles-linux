#!/usr/bin/env bash
# Resolve local package recipes to the latest stable release or default-branch
# commit. The installer runs this against an ephemeral recipe copy; passing the
# tracked packages directory updates the repository snapshots in place.
set -Eeuo pipefail

recipes_root=${1:?usage: packages/update.sh RECIPES_ROOT arch|fedora}
distro=${2:?usage: packages/update.sh RECIPES_ROOT arch|fedora}
[[ -d $recipes_root ]] || {
	printf 'Recipe root does not exist: %s\n' "$recipes_root" >&2
	exit 1
}
case $distro in
arch | fedora) ;;
*)
	printf 'Unsupported recipe distribution: %s\n' "$distro" >&2
	exit 1
	;;
esac

for command in awk chmod cp curl jq mktemp mv rm sha256sum touch; do
	command -v "$command" >/dev/null 2>&1 || {
		printf 'Recipe updater requires %s\n' "$command" >&2
		exit 1
	}
done

workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
curl_options=(
	--fail --silent --show-error --location
	--connect-timeout 20 --retry 3 --retry-all-errors
)
download_index=0
rewrite_index=0

curl_stdout() {
	curl "${curl_options[@]}" "$1"
}

github_api() {
	local endpoint=${1:?GitHub API endpoint required}
	local headers=(
		-H 'Accept: application/vnd.github+json'
		-H 'X-GitHub-Api-Version: 2022-11-28'
	)
	if [[ -n ${GITHUB_TOKEN:-} ]]; then
		headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
	fi
	curl "${curl_options[@]}" "${headers[@]}" \
		"https://api.github.com$endpoint"
}

validate_tag() {
	[[ $1 =~ ^[vV]?[0-9][0-9A-Za-z._+-]*$ ]] || {
		printf 'Unsafe upstream tag: %s\n' "$1" >&2
		exit 1
	}
}

validate_version() {
	# Hyphens are invalid in PKGBUILD pkgver and RPM Version fields.
	[[ $1 =~ ^[0-9][0-9A-Za-z._+]*$ ]] || {
		printf 'Unsafe upstream version: %s\n' "$1" >&2
		exit 1
	}
}

validate_commit() {
	[[ $1 =~ ^[0-9a-fA-F]{40}$ ]] || {
		printf 'Unsafe upstream commit: %s\n' "$1" >&2
		exit 1
	}
}

release_resolve() {
	local repository=${1:?GitHub repository required}
	local response
	response=$(github_api "/repos/$repository/releases/latest")
	RELEASE_TAG=$(jq -er '.tag_name' <<<"$response")
	validate_tag "$RELEASE_TAG"
	RELEASE_VERSION=${RELEASE_TAG#v}
	RELEASE_VERSION=${RELEASE_VERSION#V}
	validate_version "$RELEASE_VERSION"
}

head_resolve() {
	local repository=${1:?GitHub repository required}
	local metadata_path=${2:?metadata path required}
	local repository_json branch commit_json metadata
	repository_json=$(github_api "/repos/$repository")
	branch=$(jq -er '.default_branch' <<<"$repository_json")
	[[ $branch =~ ^[0-9A-Za-z._/-]+$ ]] || {
		printf 'Unsafe default branch for %s: %s\n' "$repository" "$branch" >&2
		exit 1
	}
	commit_json=$(github_api "/repos/$repository/commits/$branch")
	HEAD_COMMIT=$(jq -er '.sha' <<<"$commit_json")
	validate_commit "$HEAD_COMMIT"
	metadata=$(curl_stdout \
		"https://raw.githubusercontent.com/$repository/$HEAD_COMMIT/$metadata_path")
	HEAD_VERSION=$(jq -er '.KPlugin.Version | tostring' <<<"$metadata")
	validate_version "$HEAD_VERSION"
}

hash_url() {
	local url=${1:?source URL required}
	local destination hash
	download_index=$((download_index + 1))
	destination="$workdir/source-$download_index"
	curl "${curl_options[@]}" --output "$destination" "$url"
	hash=$(sha256sum "$destination" | awk '{print $1}')
	[[ $hash =~ ^[0-9a-f]{64}$ ]] || {
		printf 'Could not hash source: %s\n' "$url" >&2
		exit 1
	}
	printf '%s\n' "$hash"
}

mark_resolved() {
	touch "${1:?recipe directory required}/.resolved"
}

replace_line() {
	local file=${1:?file required}
	local pattern=${2:?line pattern required}
	local replacement=${3-}
	local temporary
	[[ -f $file ]] || {
		printf 'Recipe file does not exist: %s\n' "$file" >&2
		exit 1
	}
	rewrite_index=$((rewrite_index + 1))
	temporary="$workdir/rewrite-$rewrite_index"
	if ! awk -v pattern="$pattern" -v replacement="$replacement" '
		$0 ~ pattern { matches++; print replacement; next }
		{ print }
		END { if (matches != 1) exit 1 }
	' "$file" >"$temporary"; then
		printf 'Expected exactly one %s line in %s\n' "$pattern" "$file" >&2
		exit 1
	fi
	chmod --reference="$file" "$temporary"
	mv -f -- "$temporary" "$file"
}

update_arch_overview() {
	local directory="$recipes_root/arch/plasma6-applets-overview-widget"
	local recipe="$directory/PKGBUILD"
	local archive_url archive_hash
	head_resolve HimDek/Overview-Widget-for-Plasma metadata.json
	archive_url="https://github.com/HimDek/Overview-Widget-for-Plasma/archive/$HEAD_COMMIT.tar.gz"
	archive_hash=$(hash_url "$archive_url")
	replace_line "$recipe" '^pkgver=' "pkgver=$HEAD_VERSION"
	replace_line "$recipe" '^_commit=' "_commit=$HEAD_COMMIT"
	replace_line "$recipe" '^sha256sums=' "sha256sums=('$archive_hash')"
	mark_resolved "$directory"
	printf 'Resolved %-42s %s (%s)\n' \
		plasma6-applets-overview-widget "$HEAD_VERSION" "${HEAD_COMMIT:0:7}"
}

update_fedora_appmanager() {
	local directory="$recipes_root/fedora/appmanager"
	local recipe="$directory/appmanager.spec"
	local archive_url archive_hash
	release_resolve kem-a/AppManager
	archive_url="https://github.com/kem-a/AppManager/archive/refs/tags/$RELEASE_TAG.tar.gz"
	archive_hash=$(hash_url "$archive_url")
	replace_line "$recipe" '^%global tag ' "%global tag $RELEASE_TAG"
	replace_line "$recipe" '^Version:[[:space:]]' "Version:        $RELEASE_VERSION"
	printf '%s  %s.tar.gz\n' "$archive_hash" "$RELEASE_TAG" \
		>"$directory/sources.sha256"
	mark_resolved "$directory"
	printf 'Resolved %-42s %s\n' appmanager "$RELEASE_VERSION"
}

update_fedora_uosc() {
	local directory="$recipes_root/fedora/mpv-uosc"
	local recipe="$directory/mpv-uosc.spec"
	local base archive_hash config_hash license_hash
	release_resolve tomasklaen/uosc
	base="https://github.com/tomasklaen/uosc"
	archive_hash=$(hash_url "$base/releases/download/$RELEASE_TAG/uosc.zip")
	config_hash=$(hash_url "$base/releases/download/$RELEASE_TAG/uosc.conf")
	license_hash=$(hash_url "$base/raw/$RELEASE_TAG/LICENSE.LGPL")
	replace_line "$recipe" '^%global tag ' "%global tag $RELEASE_TAG"
	replace_line "$recipe" '^Version:[[:space:]]' "Version:        $RELEASE_VERSION"
	{
		printf '%s  uosc.zip\n' "$archive_hash"
		printf '%s  uosc.conf\n' "$config_hash"
		printf '%s  LICENSE.LGPL\n' "$license_hash"
	} >"$directory/sources.sha256"
	mark_resolved "$directory"
	printf 'Resolved %-42s %s\n' mpv-uosc "$RELEASE_VERSION"
}

update_fedora_overview() {
	local directory="$recipes_root/fedora/plasma6-applets-overview-widget"
	local recipe="$directory/plasma6-applets-overview-widget.spec"
	local archive_url archive_hash
	head_resolve HimDek/Overview-Widget-for-Plasma metadata.json
	archive_url="https://github.com/HimDek/Overview-Widget-for-Plasma/archive/$HEAD_COMMIT.tar.gz"
	archive_hash=$(hash_url "$archive_url")
	replace_line "$recipe" '^%global commit ' "%global commit $HEAD_COMMIT"
	replace_line "$recipe" '^Version:[[:space:]]' "Version:        $HEAD_VERSION"
	printf '%s  %s.tar.gz\n' "$archive_hash" "$HEAD_COMMIT" \
		>"$directory/sources.sha256"
	mark_resolved "$directory"
	printf 'Resolved %-42s %s (%s)\n' \
		plasma6-applets-overview-widget "$HEAD_VERSION" "${HEAD_COMMIT:0:7}"
}

update_fedora_wallhaven() {
	local directory="$recipes_root/fedora/plasma6-applets-wallhaven-reborn"
	local recipe="$directory/plasma6-applets-wallhaven-reborn.spec"
	local repository=Blacksuan19/plasma-wallpaper-wallhaven-reborn
	local archive_url archive_hash
	head_resolve "$repository" package/metadata.json
	archive_url="https://github.com/$repository/archive/$HEAD_COMMIT.tar.gz"
	archive_hash=$(hash_url "$archive_url")
	replace_line "$recipe" '^%global commit ' "%global commit $HEAD_COMMIT"
	replace_line "$recipe" '^Version:[[:space:]]' "Version:        $HEAD_VERSION"
	printf '%s  %s.tar.gz\n' "$archive_hash" "$HEAD_COMMIT" \
		>"$directory/sources.sha256"
	mark_resolved "$directory"
	printf 'Resolved %-42s %s (%s)\n' \
		plasma6-applets-wallhaven-reborn "$HEAD_VERSION" "${HEAD_COMMIT:0:7}"
}

case $distro in
arch)
	update_arch_overview
	;;
fedora)
	update_fedora_appmanager
	update_fedora_uosc
	update_fedora_overview
	update_fedora_wallhaven
	;;
esac

for recipe_directory in "$recipes_root/$distro"/*; do
	[[ -d $recipe_directory ]] || continue
	[[ -f $recipe_directory/.resolved ]] || {
		printf 'Local recipe has no updater: %s\n' "$recipe_directory" >&2
		exit 1
	}
	rm -f -- "$recipe_directory/.resolved"
done
