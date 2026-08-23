#!/usr/bin/env bash
## AppImage support through AppManager
## https://aur.archlinux.org/packages/appmanager
## https://github.com/kem-a/AppManager
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

case "$DISTRO" in
	arch)
		runtime_packages=(
			ca-certificates dwarfs gtk4 json-glib libadwaita libgee libsoup3
			libsecret gnutls squashfs-tools
		)
		build_packages=(meson ninja vala gcc pkgconf gettext curl)
		;;
	fedora)
		runtime_packages=(
			ca-certificates gtk4 json-glib libadwaita libgee libsoup3
			libsecret gnutls squashfs-tools
		)
		build_packages=(
			meson ninja-build vala gcc pkgconf-pkg-config gettext curl
			glib2-devel gtk4-devel json-glib-devel libadwaita-devel libgee-devel
			libsoup3-devel libsecret-devel gnutls-devel
		)
		;;
	*)
		printf 'Unsupported distro: %s\n' "$DISTRO" >&2
		exit 1
		;;
esac

pkg_install "${runtime_packages[@]}"

install_appmanager() (
	set -Eeuo pipefail
	local archive tmpdir stage
	local version=3.7.3
	local checksum=c900f7d97a94c72ab52e534d019f776b643147a4164fef0d56052ef15125efe0
	tmpdir=$(mktemp -d)
	stage="$tmpdir/stage"
	archive="$tmpdir/AppManager.tar.gz"
	trap 'rm -rf -- "$tmpdir"' EXIT

	github_download \
		"https://github.com/kem-a/AppManager/archive/refs/tags/v${version}.tar.gz" \
		"$archive"
	printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status
	mkdir -p "$tmpdir/source" "$stage"
	tar -xzf "$archive" --strip-components=1 -C "$tmpdir/source"
	meson setup "$tmpdir/source" "$tmpdir/build" \
		--prefix=/usr \
		-Dbundle_dwarfs=false \
		-Dbundle_zsync=false \
		-Dbundle_unsquashfs=false
	meson compile -C "$tmpdir/build"
	DESTDIR="$stage" meson install -C "$tmpdir/build" --no-rebuild
	cp -a --no-preserve=ownership -- "$stage/." /
	glib-compile-schemas /usr/share/glib-2.0/schemas
)

pkg_from_source install_appmanager "${build_packages[@]}"

# Delta updates (zsync2) and DwarFS extraction are unavailable on Fedora and
# zsync2 is not a native Arch repository package. AppManager still installs and
# manages ordinary SquashFS AppImages without FUSE 2.
