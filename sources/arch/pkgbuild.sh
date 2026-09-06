#!/usr/bin/env bash

source_uses_local_packages=true

_PKGBUILD_USER=system-aur
_PKGBUILD_HOME=/var/lib/$PROJECT_ID/aur
_PKGBUILD_READY=/var/lib/$PROJECT_ID/pkgbuild-ready

_pkgbuild_make() {
	local directory=${1:?A build directory is required}
	sudo --user "$_PKGBUILD_USER" \
		env HOME="$_PKGBUILD_HOME" \
		bash -c 'cd -- "$1" && exec makepkg --noconfirm --needed --syncdeps --install --cleanbuild --clean' \
		bash "$directory"
}

_pkgbuild_setup() {
	if [[ -f $_PKGBUILD_READY ]] && id "$_PKGBUILD_USER" >/dev/null 2>&1; then
		return
	fi

	pkg_install base-devel sudo

	install -d -m 0755 "/var/lib/$PROJECT_ID"
	if ! id "$_PKGBUILD_USER" >/dev/null 2>&1; then
		useradd --system --create-home --home-dir "$_PKGBUILD_HOME" \
			--shell /usr/bin/nologin "$_PKGBUILD_USER"
	fi
	local sudoers="/etc/sudoers.d/$_PKGBUILD_USER"
	printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$_PKGBUILD_USER" >"$sudoers"
	chmod 0440 "$sudoers"

	touch "$_PKGBUILD_READY"
	chown root:root "$_PKGBUILD_READY"
	chmod 0644 "$_PKGBUILD_READY"
}

_pkgbuild_install_recipe() (
	set -Eeuo pipefail
	local package=${1:?local package required}
	[[ $package =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$ ]] || {
		printf 'Invalid local package name: %s\n' "$package" >&2
		return 1
	}
	local recipes_root=${PACKAGE_RECIPE_ROOT:-$SETUP_ROOT/packages}
	local recipe="$recipes_root/arch/$package"
	[[ -f $recipe/PKGBUILD ]] || {
		printf 'No tracked PKGBUILD for %s\n' "$package" >&2
		return 1
	}

	local build_directory
	build_directory=$(mktemp -d /tmp/system-pkgbuild.XXXXXX)
	trap 'rm -rf -- "$build_directory"' EXIT
	cp -a -- "$recipe/." "$build_directory/"
	chown -R "$_PKGBUILD_USER:$_PKGBUILD_USER" "$build_directory"
	_pkgbuild_make "$build_directory"
)

source_prepare() {
	_pkgbuild_setup
}

source_install() {
	source_prepare
	local package
	for package in "$@"; do
		_pkgbuild_install_recipe "$package"
	done
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
