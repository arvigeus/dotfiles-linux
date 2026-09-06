#!/usr/bin/env bash

source_uses_local_packages=true

_RPMSPEC_USER=system-rpm
_RPMSPEC_HOME=/var/lib/$PROJECT_ID/rpm
_RPMSPEC_READY=/var/lib/$PROJECT_ID/rpmspec-ready

_rpmspec_setup() {
	if [[ -f $_RPMSPEC_READY ]] && id "$_RPMSPEC_USER" >/dev/null 2>&1; then
		return
	fi

	pkg_install dnf-plugins-core rpm-build rpmdevtools sudo

	install -d -m 0755 "/var/lib/$PROJECT_ID"
	if ! id "$_RPMSPEC_USER" >/dev/null 2>&1; then
		useradd --system --create-home --home-dir "$_RPMSPEC_HOME" \
			--shell /usr/sbin/nologin "$_RPMSPEC_USER"
	fi

	touch "$_RPMSPEC_READY"
	chown root:root "$_RPMSPEC_READY"
	chmod 0644 "$_RPMSPEC_READY"
}

_rpmspec_install_recipe() (
	set -Eeuo pipefail
	local package=${1:?local package required}
	[[ $package =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$ ]] || {
		printf 'Invalid local package name: %s\n' "$package" >&2
		return 1
	}

	local recipes_root=${PACKAGE_RECIPE_ROOT:-$SETUP_ROOT/packages}
	local recipe="$recipes_root/fedora/$package"
	local spec="$recipe/$package.spec"
	[[ -f $spec && -f $recipe/sources.sha256 ]] || {
		printf 'No tracked RPM recipe for %s\n' "$package" >&2
		return 1
	}

	local build_directory recipe_copy topdir
	build_directory=$(mktemp -d /tmp/system-rpmspec.XXXXXX)
	trap 'rm -rf -- "$build_directory"' EXIT
	recipe_copy="$build_directory/recipe"
	topdir="$build_directory/rpmbuild"
	mkdir -p "$recipe_copy"
	cp -a -- "$recipe/." "$recipe_copy/"
	chown -R "$_RPMSPEC_USER:$_RPMSPEC_USER" "$build_directory"

	# Resolve BuildRequires through DNF, then download and verify every Source
	# as the unprivileged package builder.
	dnf -y builddep "$recipe_copy/$package.spec"
	sudo --user "$_RPMSPEC_USER" \
		env HOME="$_RPMSPEC_HOME" \
		bash -c '
			set -Eeuo pipefail
			recipe=$1
			topdir=$2
			package=$3
			mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
			cp -a -- "$recipe/." "$topdir/SOURCES/"
			rm -f -- \
				"$topdir/SOURCES/$package.spec" \
				"$topdir/SOURCES/sources.sha256" \
				"$topdir/SOURCES/update.sh"
			cp -- "$recipe/$package.spec" "$topdir/SPECS/"
			spectool --get-files --directory "$topdir/SOURCES" \
				"$topdir/SPECS/$package.spec"
			(
				cd "$topdir/SOURCES"
				sha256sum --check --strict "$recipe/sources.sha256"
				for source in *; do
					awk -v source="$source" \
						"\$2 == source { found = 1 } END { exit !found }" \
						"$recipe/sources.sha256" || {
						printf "Source is not checksummed: %s\n" "$source" >&2
						exit 1
					}
				done
			)
			rpmbuild -bb \
				--define "_topdir $topdir" \
				"$topdir/SPECS/$package.spec"
		' bash "$recipe_copy" "$topdir" "$package"

	local rpms=()
	mapfile -d '' rpms < <(find "$topdir/RPMS" -type f -name '*.rpm' -print0)
	((${#rpms[@]} > 0)) || {
		printf 'RPM recipe produced no packages: %s\n' "$package" >&2
		return 1
	}
	pkg_native_install "${rpms[@]}"
)

source_prepare() {
	_rpmspec_setup
}

source_install() {
	source_prepare
	local package
	for package in "$@"; do
		_rpmspec_install_recipe "$package"
	done
}

source_is_installed() {
	pkg_native_is_installed "$1"
}

source_remove() {
	pkg_native_remove "$@"
}
