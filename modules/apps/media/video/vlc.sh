#!/usr/bin/env bash
## VLC media player
## https://www.videolan.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

repo_health https://github.com/nurupo/vlc-pause-click-plugin -m 36

packages=(
	vlc
	vlc-plugins-all
	fedora:vlc-plugin-pause-click
	arch:aur/vlc-pause-click-plugin
)
pkg_install "${packages[@]}"

# Global baseline. VLC may create per-user overrides during normal use.
file_write /etc/vlc/vlcrc <<'EOF'
[core]
metadata-network-access=1
one-instance=1
playlist-enqueue=1
audio-language=jpn,jp,eng,en
sub-language=eng,en,bg,vi,vn
snapshot-path=~/Pictures
snapshot-prefix=vlc-

[qt]
qt-privacy-ask=0
qt-minimal-view=1
qt-system-tray=0
qt-pause-minimized=1
qt-dark-palette=1
qt-max-volume=200
EOF
