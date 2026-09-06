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

for command in awk chmod cp curl grep jq mktemp mv rm sed sha256sum touch; do
	command -v "$command" >/dev/null 2>&1 || {
		printf 'Recipe updater requires %s\n' "$command" >&2
		exit 1
	}
done

workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
curl_options=(
	--fail --silent --show-error --location
	--connect-timeout 20 --max-time 300 --retry 3 --retry-all-errors
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

head_commit_resolve() {
	local repository=${1:?GitHub repository required}
	local repository_json branch commit_json timestamp
	repository_json=$(github_api "/repos/$repository")
	branch=$(jq -er '.default_branch' <<<"$repository_json")
	[[ $branch =~ ^[0-9A-Za-z._/-]+$ ]] || {
		printf 'Unsafe default branch for %s: %s\n' "$repository" "$branch" >&2
		exit 1
	}
	commit_json=$(github_api "/repos/$repository/commits/$branch")
	HEAD_COMMIT=$(jq -er '.sha' <<<"$commit_json")
	validate_commit "$HEAD_COMMIT"
	timestamp=$(jq -er '.commit.author.date' <<<"$commit_json")
	[[ $timestamp =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] || {
		printf 'Unsafe commit timestamp for %s: %s\n' "$repository" "$timestamp" >&2
		exit 1
	}
	HEAD_DATE=${timestamp%%T*}
	HEAD_DATE=${HEAD_DATE//-/}
}

hash_url() {
	local url=${1:?source URL required}
	local cache_name=${2:-}
	local destination hash
	download_index=$((download_index + 1))
	destination="$workdir/source-$download_index"
	curl "${curl_options[@]}" --output "$destination" "$url"
	hash=$(sha256sum "$destination" | awk '{print $1}')
	[[ $hash =~ ^[0-9a-f]{64}$ ]] || {
		printf 'Could not hash source: %s\n' "$url" >&2
		exit 1
	}
	if [[ -n $cache_name ]]; then
		[[ $cache_name != */* && $cache_name != *[[:space:]]* ]] || {
			printf 'Unsafe cached source name: %s\n' "$cache_name" >&2
			exit 1
		}
		cp -- "$destination" "$RECIPE_DIR/$cache_name"
	fi
	printf '%s\n' "$hash"
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

for recipe_directory in "$recipes_root/$distro"/*; do
	[[ -d $recipe_directory ]] || continue
	updater="$recipe_directory/update.sh"
	[[ -f $updater && ! -L $updater ]] || {
		printf 'Local recipe has no updater: %s\n' "$recipe_directory" >&2
		exit 1
	}
	(
		set -Eeuo pipefail
		# shellcheck disable=SC2034 # consumed by the sourced recipe updater
		RECIPE_DIR=$recipe_directory
		# shellcheck disable=SC1090
		source "$updater"
	)
done
