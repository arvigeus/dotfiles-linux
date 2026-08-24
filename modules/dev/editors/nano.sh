#!/usr/bin/env bash
## Nano - Text Editor
## https://www.nano-editor.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

repo_health https://github.com/galenguyer/nano-syntax-highlighting -m 12

packages=(
	nano
	arch:nano-syntax-highlighting
)
pkg_install "${packages[@]}"

file_write "/etc/nanorc" <<'EOF'
# Syntax highlighting
include "/usr/share/nano/*.nanorc"
include "/usr/share/nano/extra/*.nanorc"
include "/usr/share/nano-syntax-highlighting/*.nanorc"

set autoindent
set linenumbers
set mouse
set smarthome
set tabsize 4
set tabstospaces
set trimblanks
EOF

# https://gitlab.archlinux.org/archlinux/packaging/packages/nano-syntax-highlighting/-/blob/main/PKGBUILD
install_nano_syntax_highlighting() (
	local tag tmpdir
	tag=$(github_latest_tag "galenguyer/nano-syntax-highlighting")
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	github_download \
		"https://github.com/galenguyer/nano-syntax-highlighting/archive/refs/tags/${tag}.tar.gz" \
		"$tmpdir/source.tar.gz"
	mkdir -p "$tmpdir/source"
	tar -xzf "$tmpdir/source.tar.gz" --strip-components=1 -C "$tmpdir/source"
	find "$tmpdir/source" -mindepth 1 -maxdepth 1 ! -name '*.nanorc' -exec rm -rf {} +
	file_install_tree "$tmpdir/source" /usr/share/nano-syntax-highlighting
)

[[ $DISTRO != fedora ]] || install_nano_syntax_highlighting
