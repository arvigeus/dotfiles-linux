#!/usr/bin/env bash
## XDG user directories (Desktop, Documents, Downloads, ...)
## https://wiki.archlinux.org/title/XDG_user_directories
## https://wiki.archlinux.org/title/XDG_Base_Directory
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	xdg-user-dirs
)

module_apply() {
	# Global user-directory defaults. xdg-user-dirs-update + the
	# xdg-user-dirs.service user unit create these under $HOME at login.
	# Standard eight plus the PROJECTS extension already used on this
	# machine, so static configs referencing ~/Pictures (mpv, vlc)
	# coincide with XDG_PICTURES_DIR.
	file_write /etc/xdg/user-dirs.defaults <<'EOF'
DESKTOP=Desktop
DOWNLOAD=Downloads
TEMPLATES=Templates
PUBLICSHARE=Public
DOCUMENTS=Documents
MUSIC=Music
PICTURES=Pictures
VIDEOS=Videos
PROJECTS=Projects
EOF

	# Seed the per-user mapping. Keep user edits: install only when missing
	# and never delete a user-modified file removed from the skeleton.
	file_write "$HOME/.config/user-dirs.dirs" <<'EOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
XDG_PROJECTS_DIR="$HOME/Projects"
EOF
	home_strategy .config/user-dirs.dirs keep unchanged
}

module_entrypoint "$@"
