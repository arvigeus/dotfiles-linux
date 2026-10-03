#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin"
cat >"$TEST_ROOT/bin/gh" <<'GH'
#!/usr/bin/env bash
[[ $* == 'auth status' ]]
GH
cat >"$TEST_ROOT/bin/git" <<'GIT'
#!/usr/bin/env bash
set -eu
for last; do :; done
mkdir -p "$last/ssh"
printf 'fixture, not a credential\n' >"$last/ssh/key"
printf 'touch "$TEST_HYDRATION_SENTINEL"\n' >"$last/legacy.sh"
if [[ ${TEST_SYMLINK:-false} == true ]]; then
	ln -s /etc/passwd "$last/ssh/link"
fi
if [[ ${TEST_HOOK:-false} == true ]]; then
	printf 'umask 077; touch "$TEST_HYDRATION_SENTINEL"; echo private-hook-output\n' >"$last/hydrate.sh"
fi
GIT
chmod +x "$TEST_ROOT/bin/"*
export PATH="$TEST_ROOT/bin:$PATH"
export XDG_DATA_HOME="$TEST_ROOT/data"
export TEST_HYDRATION_SENTINEL="$TEST_ROOT/ran"
if ((EUID == 0)); then
	if bash "$PROJECT_ROOT/hydrate-private.sh" >/dev/null 2>&1; then exit 1; fi
	printf 'private hydration root refusal: ok (user-path checks require non-root)\n'
	exit 0
fi
bash "$PROJECT_ROOT/hydrate-private.sh" >"$TEST_ROOT/output"
repo="$XDG_DATA_HOME/system-private/repository"
[[ $(stat -c %a "$repo") == 700 && $(stat -c %a "$repo/ssh/key") == 600 ]]
[[ ! -e $TEST_HYDRATION_SENTINEL ]]
if bash "$PROJECT_ROOT/hydrate-private.sh" >/dev/null 2>&1; then exit 1; fi
[[ -s $repo/ssh/key ]]
XDG_DATA_HOME="$TEST_ROOT/unsafe" TEST_SYMLINK=true
export XDG_DATA_HOME TEST_SYMLINK
if bash "$PROJECT_ROOT/hydrate-private.sh" >/dev/null 2>&1; then exit 1; fi
[[ ! -e $XDG_DATA_HOME/system-private/repository ]]
XDG_DATA_HOME="$TEST_ROOT/apply" TEST_SYMLINK=false TEST_HOOK=true
export XDG_DATA_HOME TEST_SYMLINK TEST_HOOK
bash "$PROJECT_ROOT/hydrate-private.sh" --apply >"$TEST_ROOT/apply-output"
[[ -e $TEST_HYDRATION_SENTINEL ]]
[[ $(stat -c %a "$XDG_DATA_HOME/system-private/apply.log") == 600 ]]
if rg -q 'private-hook-output' "$TEST_ROOT/apply-output"; then exit 1; fi
printf 'private hydration isolation and permissions: ok\n'
