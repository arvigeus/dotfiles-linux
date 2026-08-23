#!/usr/bin/env bash
## GIMP and system-preinstalled Flatpak plug-ins
## https://www.gimp.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

repo_health https://github.com/bootchk/resynthesizer -m 12
repo_health https://github.com/rpeyron/plugin-gimp-fourier -m 12
repo_health https://github.com/kamilburda/batcher -m 12

packages=(
	flathub/org.gimp.GIMP
	flathub/runtime/org.gimp.GIMP.Plugin.Resynthesizer/x86_64/3
	flathub/runtime/org.gimp.GIMP.Plugin.Fourier/x86_64/3
	flathub/runtime/org.gimp.GIMP.Plugin.GMic/x86_64/3
)
pkg_install "${packages[@]}"
flatpak_alias gimp org.gimp.GIMP

install_batcher() (
	set -Eeuo pipefail
	local tag tmpdir archive source plugins_dir
	tag=$(github_latest_tag kamilburda/batcher)
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	archive="$tmpdir/batcher.zip"
	github_download \
		"https://github.com/kamilburda/batcher/releases/download/${tag}/batcher-${tag}.zip" \
		"$archive"
	unzip -q "$archive" -d "$tmpdir/unpacked"
	source="$tmpdir/unpacked/batcher"
	[[ -d $source ]] || {
		printf 'Batcher archive does not contain a batcher directory\n' >&2
		return 1
	}
	plugins_dir="$HOME/.var/app/org.gimp.GIMP/config/GIMP/3.0/plug-ins"
	file_install_tree "$source" "$plugins_dir/batcher"
)

pkg_from_source install_batcher curl jq unzip
