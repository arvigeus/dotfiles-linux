#!/usr/bin/env bash
## yt-dlp — feature-rich command-line audio/video downloader
## https://github.com/yt-dlp/yt-dlp
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	yt-dlp
	flathub/org.nickvision.tubeconverter
)

module_apply() {

	flatpak_alias parabolic org.nickvision.tubeconverter

	## Tips:
	## - Auto-generated subtitles:
	##     yt-dlp <url> --write-auto-sub --sub-lang en
	## - Useful options to combine:
	##     --netrc --sponsorblock-remove all --add-chapters \
	##     -o '%(title)s.%(ext)s' \
	##     -f "(bv*[vcodec~='^((he|a)vc|h26[45])']+ba*[ext=m4a]) / (bv*+ba/b)" \
	##     --write-sub --sub-lang 'en.*' --convert-subs srt --embed-subs
}

module_entrypoint "$@"
