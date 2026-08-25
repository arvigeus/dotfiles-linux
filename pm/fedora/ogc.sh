#!/usr/bin/env bash

_OGC_FEDORA_IMAGE=ghcr.io/opengamingcollective/kernel-packages-fedora

_ogc_fedora_version() {
	local version
	version=$(
		# shellcheck disable=SC1091
		source /etc/os-release
		printf '%s\n' "${VERSION_ID:-}"
	)
	case $version in
	43 | 44) printf '%s\n' "$version" ;;
	*)
		printf 'OGC does not publish a Fedora kernel artifact for Fedora %s\n' "${version:-unknown}" >&2
		return 1
		;;
	esac
}

pm_enable() {
	_ogc_fedora_version >/dev/null
}

pm_install() (
	set -Eeuo pipefail
	local package
	for package in "$@"; do
		[[ $package == kernel ]] || {
			printf 'Unsupported Fedora OGC package: %s\n' "$package" >&2
			return 1
		}
	done
	pm_enable

	local version repository tag token manifest work
	version=$(_ogc_fedora_version)
	repository=${_OGC_FEDORA_IMAGE#ghcr.io/}
	tag="latest-fc$version"
	work=$(mktemp -d /tmp/system-ogc-fedora.XXXXXX)
	trap 'rm -rf -- "$work"' EXIT

	token=$(curl -fsSL \
		"https://ghcr.io/token?scope=repository:$repository:pull" | jq -er '.token')
	manifest="$work/manifest.json"
	curl -fsSL \
		-H "Authorization: Bearer $token" \
		-H 'Accept: application/vnd.oci.image.manifest.v1+json' \
		"https://ghcr.io/v2/$repository/manifests/$tag" >"$manifest"

	local layers=()
	mapfile -t layers < <(
		jq -er '.layers[] |
			select(.annotations["org.opencontainers.image.title"] |
				test("^kernel(-core|-modules)?-[0-9][^/]*\\.rpm$")) |
			[.digest, .annotations["org.opencontainers.image.title"]] | @tsv' \
			"$manifest"
	)
	((${#layers[@]} == 3)) || {
		printf 'Expected three core OGC kernel RPMs, found %d\n' "${#layers[@]}" >&2
		return 1
	}

	local layer digest filename destination expected actual rpms=()
	for layer in "${layers[@]}"; do
		IFS=$'\t' read -r digest filename <<<"$layer"
		[[ $digest =~ ^sha256:[a-f0-9]{64}$ && $filename != */* ]] || {
			printf 'Invalid OGC OCI layer: %s\n' "$layer" >&2
			return 1
		}
		destination="$work/$filename"
		curl -fsSL \
			-H "Authorization: Bearer $token" \
			"https://ghcr.io/v2/$repository/blobs/$digest" >"$destination"
		expected=${digest#sha256:}
		actual=$(sha256sum "$destination")
		actual=${actual%% *}
		[[ $actual == "$expected" ]] || {
			printf 'Digest mismatch for OGC kernel RPM: %s\n' "$filename" >&2
			return 1
		}
		[[ $(rpm -qp --queryformat '%{RELEASE}' "$destination") == ogc* ]] || {
			printf 'Downloaded RPM is not an OGC kernel build: %s\n' "$filename" >&2
			return 1
		}
		rpms+=("$destination")
	done

	dnf -y install "${rpms[@]}"
)

pm_is_installed() {
	[[ $1 == kernel ]] || return 1
	rpm -qa --queryformat '%{NAME}\t%{RELEASE}\n' |
		awk -F '\t' '$1 == "kernel" && $2 ~ /^ogc/ { found=1 } END { exit !found }'
}

pm_remove() {
	local package
	for package in "$@"; do
		[[ $package == kernel ]] || {
			printf 'Unsupported Fedora OGC package: %s\n' "$package" >&2
			return 1
		}
	done
	local installed=()
	mapfile -t installed < <(
		rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' |
			awk '$0 ~ /-ogc[^-]*\.[^.]+$/ && $0 ~ /^kernel(-core|-modules)?-/ { print }'
	)
	((${#installed[@]} == 0)) || dnf -y remove --no-autoremove "${installed[@]}"
}
