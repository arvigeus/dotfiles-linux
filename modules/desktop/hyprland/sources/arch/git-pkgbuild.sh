#!/usr/bin/env bash
# Native recipes maintained in an external Git repository. The opaque source
# name is HOST/PATH (HTTPS, default branch); all split package outputs install.
# Kept module-local while only one leaf consumes it.
source "$SETUP_ROOT/sources/arch/pkgbuild.sh"
# shellcheck disable=SC2034 # read by the package planner
source_uses_local_packages=false
_GIT_PKGBUILD_STATE_ROOT=/var/lib/$PROJECT_ID/git-pkgbuild

_git_pkgbuild_ref() {
	local repository=${1:?repository required}
	[[ $repository =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+/[a-zA-Z0-9._/-]+$ &&
		$repository != */ && $repository != *//* && $repository != */.* ]] || {
		printf 'Invalid Git PKGBUILD repository: %s\n' "$repository" >&2
		return 1
	}
	GIT_PKGBUILD_URL="https://$repository.git"
	GIT_PKGBUILD_STATE="$_GIT_PKGBUILD_STATE_ROOT/$(printf '%s' "$repository" | sha256sum | cut -d ' ' -f1).srcinfo"
}

_git_pkgbuild_install() (
	set -Eeuo pipefail
	_git_pkgbuild_ref "$1" || return
	local work
	work=$(mktemp -d /tmp/system-git-pkgbuild.XXXXXX) || return
	trap 'rm -rf -- "$work"' EXIT
	chmod 0755 "$work" || return
	if [[ -n ${GIT_PKGBUILD_LOCAL_DIR:-} ]]; then
		local checkout
		checkout=$(realpath -- "$GIT_PKGBUILD_LOCAL_DIR") || return
		[[ -f $checkout/PKGBUILD && -d $checkout/.git ]] || {
			printf 'Local override must be a Git checkout with a root PKGBUILD\n' >&2
			return 1
		}
		# The explicit user-owned checkout is trusted only for this clone; root's
		# Git ownership check otherwise rejects a local source from another UID.
		git -c safe.directory="$checkout" -c safe.directory="$checkout/.git" \
			clone --quiet --no-hardlinks -- "$checkout" "$work/checkout" || return
		while IFS= read -r -d '' file; do
			if [[ -e $checkout/$file || -L $checkout/$file ]]; then printf '%s\0' "$file"; fi
		done < <(git -c safe.directory="$checkout" -C "$checkout" ls-files --cached --others --exclude-standard -z) |
			tar -C "$checkout" --null -T - -cf - |
			tar -xf - -C "$work/checkout" || return
		while IFS= read -r -d '' deleted; do rm -f -- "$work/checkout/$deleted"; done \
			< <(git -c safe.directory="$checkout" -C "$checkout" ls-files --deleted -z)
		git -C "$work/checkout" add -A || return
		if ! git -C "$work/checkout" diff --cached --quiet; then
			git -C "$work/checkout" -c commit.gpgsign=false -c user.name='Local package build' \
				-c user.email='local@localhost' commit --quiet -m 'Local working tree snapshot' || return
		fi
	else
		git clone --quiet -- "$GIT_PKGBUILD_URL" "$work/checkout" || return
	fi
	[[ -f $work/checkout/PKGBUILD && ! -L $work/checkout/PKGBUILD ]] || {
		printf 'Repository has no root PKGBUILD: %s\n' "$1" >&2
		return 1
	}
	chown -R "$_PKGBUILD_USER:$_PKGBUILD_USER" "$work/checkout" || return
	# Native makepkg fetches the same checkout that supplied the recipe. Git's
	# standard URL rewrite prevents a second remote fetch and metadata/HEAD races.
	_pkgbuild_make "$work/checkout" \
		GIT_CONFIG_COUNT=1 \
		"GIT_CONFIG_KEY_0=url.file://$work/checkout.insteadOf" \
		"GIT_CONFIG_VALUE_0=$GIT_PKGBUILD_URL" || return
	# Installed-state queries remain native; persist generated metadata, never
	# mirror package names or dependencies in a tracked dotfiles recipe.
	local metadata
	metadata=$(sudo --user "$_PKGBUILD_USER" env HOME="$_PKGBUILD_HOME" \
		bash -c 'cd -- "$1" && exec makepkg --printsrcinfo' bash "$work/checkout") || return
	[[ $metadata == *'pkgname = '* ]] || return 1
	install -d -m 0755 "$(dirname -- "$GIT_PKGBUILD_STATE")" || return
	printf '%s\n' "$metadata" >"$GIT_PKGBUILD_STATE.tmp" || return
	mv -f -- "$GIT_PKGBUILD_STATE.tmp" "$GIT_PKGBUILD_STATE"
)

source_prepare() {
	_pkgbuild_setup
	pkg_install git
}

source_install() {
	if [[ -n ${GIT_PKGBUILD_LOCAL_DIR:-} && $# != 1 ]]; then
		printf 'Local override requires exactly one repository per source transaction\n' >&2
		return 1
	fi
	local repository
	for repository in "$@"; do _git_pkgbuild_ref "$repository" || return; done
	source_prepare
	for repository in "$@"; do _git_pkgbuild_install "$repository"; done
}

source_is_installed() {
	_git_pkgbuild_ref "$1" || return
	[[ -s $GIT_PKGBUILD_STATE ]] || return 1
	local names=() name
	mapfile -t names < <(awk '$1 == "pkgname" && $2 == "=" {print $3}' "$GIT_PKGBUILD_STATE")
	((${#names[@]} > 0)) || return 1
	for name in "${names[@]}"; do pkg_native_is_installed "$name" || return; done
}

source_remove() {
	local repository names=()
	for repository in "$@"; do
		_git_pkgbuild_ref "$repository" || return
		[[ -s $GIT_PKGBUILD_STATE ]] || {
			printf 'No installed recipe metadata for %s\n' "$repository" >&2
			return 1
		}
		mapfile -t names < <(awk '$1 == "pkgname" && $2 == "=" {print $3}' "$GIT_PKGBUILD_STATE")
		((${#names[@]} > 0)) || return 1
		pkg_native_remove "${names[@]}" || return
		rm -f -- "$GIT_PKGBUILD_STATE"
	done
}
