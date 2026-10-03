#!/usr/bin/env bash
# Explicit post-login hook; never called by bootstrap or rebuild.
set -Eeuo pipefail
umask 077
((EUID != 0)) || {
	printf 'Run private hydration as your login user, without sudo.\n' >&2
	exit 1
}
transport=gh
apply=false
for argument in "$@"; do
	case $argument in
	--ssh) transport=ssh ;;
	--apply) apply=true ;;
	--help)
		printf 'Usage: hydrate-private.sh [--ssh] [--apply]\nFetch arvigeus/dotfiles-private after login. --apply requires its reviewed hydrate.sh hook.\n'
		exit 0
		;;
	*)
		printf 'Unknown option: %s\n' "$argument" >&2
		exit 1
		;;
	esac
done
command -v git >/dev/null || {
	printf 'git is required.\n' >&2
	exit 1
}
parent=${XDG_DATA_HOME:-$HOME/.local/share}/system-private
[[ ! -L $parent ]] || {
	printf 'Private checkout parent must not be a symlink.\n' >&2
	exit 1
}
install -d -m 0700 "$parent"
staging=$(mktemp -d "$parent/fetch.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
if [[ $transport == gh ]]; then
	command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || {
		printf 'Authenticate first with gh auth login, deliberately supply GH_TOKEN, or use --ssh.\n' >&2
		exit 1
	}
	# The credential helper reads gh's credentials/environment; no secret is
	# placed in an argument, remote URL, or tracked configuration.
	git_args=(-c credential.helper= -c 'credential.helper=!gh auth git-credential')
	remote=https://github.com/arvigeus/dotfiles-private.git
else
	git_args=()
	remote=git@github.com:arvigeus/dotfiles-private.git
fi
if ! GIT_TERMINAL_PROMPT=0 git "${git_args[@]}" clone --quiet -- "$remote" "$staging/repository" >"$staging/fetch.log" 2>&1; then
	printf 'Private fetch failed. Check GitHub authentication and repository access.\n' >&2
	exit 1
fi
repository=$staging/repository
# Do not follow repository links or execute legacy scripts automatically.
if [[ -n $(find "$repository" -type l -print -quit) ]]; then
	printf 'Private checkout contains symlinks; review them before hydration.\n' >&2
	exit 1
fi
find "$repository" -type d -exec chmod 0700 {} +
find "$repository" -type f -exec chmod 0600 {} +
destination="$parent/repository"
[[ ! -e $destination && ! -L $destination ]] || {
	printf 'A private checkout already exists. Move it aside after review before fetching again.\n' >&2
	exit 1
}
mv -- "$repository" "$destination"
printf 'Private checkout fetched with owner-only permissions.\n'
if [[ $apply == true ]]; then
	[[ -f $destination/hydrate.sh ]] || {
		printf 'No reviewed hydrate.sh hook exists. Follow docs/private-hydration.md to add one; legacy scripts were not executed.\n' >&2
		exit 1
	}
	# The user's explicit --apply authorizes this private, user-owned hook.
	# Capture its output in an owner-only log in case legacy tools echo secrets.
	if ! bash "$destination/hydrate.sh" >"$parent/apply.log" 2>&1; then
		printf 'Private apply failed; inspect the owner-only local apply.log privately.\n' >&2
		exit 1
	fi
	printf 'Private hydration hook completed.\n'
fi
