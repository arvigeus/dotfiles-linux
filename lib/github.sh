#!/usr/bin/env bash

_github_api() {
	curl \
		--fail \
		--silent \
		--show-error \
		--location \
		--connect-timeout 20 \
		--max-time 120 \
		--retry 3 \
		--retry-all-errors \
		--header 'Accept: application/vnd.github+json' \
		--header 'X-GitHub-Api-Version: 2022-11-28' \
		"https://api.github.com/$1"
}

# Print the latest release tag for owner/repository.
github_latest_tag() {
	local repository=${1:?github_latest_tag requires owner/repository}
	_github_api "repos/$repository/releases/latest" | jq -er '.tag_name'
}

# Print the first latest-release asset URL whose filename matches a regex.
github_latest_download() {
	local repository=${1:?github_latest_download requires owner/repository}
	local pattern=${2:?github_latest_download requires an asset filename regex}
	_github_api "repos/$repository/releases/latest" |
		jq -er --arg pattern "$pattern" \
			'[.assets[] | select(.name | test($pattern))][0].browser_download_url'
}

# Convert a github.com blob URL to raw.githubusercontent.com.
github_raw_url() {
	printf '%s\n' "$1" |
		sed -E 's|^https://github\.com/([^/]+/[^/]+)/blob/|https://raw.githubusercontent.com/\1/|'
}

# Read a GitHub blob or raw URL to stdout.
github_read_file() {
	local url=${1:?github_read_file requires a URL}
	curl --fail --silent --show-error --location \
		--connect-timeout 20 --max-time 120 --retry 3 --retry-all-errors \
		"$(github_raw_url "$url")"
}

# Atomically download a GitHub blob or raw URL to a file.
github_download() {
	local url=${1:?github_download requires a URL}
	local output=${2:?github_download requires an output path}
	local temporary="${output}.${PROJECT_ID}-tmp"

	mkdir -p "$(dirname -- "$output")"
	rm -f -- "$temporary"
	if ! curl --fail --silent --show-error --location \
		--connect-timeout 20 --max-time 300 --retry 3 --retry-all-errors \
		--output "$temporary" "$(github_raw_url "$url")"; then
		rm -f -- "$temporary"
		return 1
	fi
	mv -f -- "$temporary" "$output"
}
