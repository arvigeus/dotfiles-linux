#!/usr/bin/env bash
## FFmpeg — audio/video conversion and processing
## https://ffmpeg.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:ffmpeg
	fedora:rpmfusion/ffmpeg
)

pkg_install "${packages[@]}"
