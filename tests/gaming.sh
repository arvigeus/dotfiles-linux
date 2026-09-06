#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SESSION="$PROJECT_ROOT/modules/gaming/gamescope-session/files/usr/local/bin/system-gaming-session"
TEST_DIRECTORY=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIRECTORY"' EXIT
: >"$TEST_DIRECTORY/empty.conf"

run_session() {
	env \
		HOME="$TEST_DIRECTORY" \
		XDG_CONFIG_HOME="$TEST_DIRECTORY" \
		SYSTEM_GAMING_SYSTEM_CONFIG="$TEST_DIRECTORY/empty.conf" \
		SYSTEM_GAMING_USER_CONFIG="$TEST_DIRECTORY/empty.conf" \
		SYSTEM_GAMING_DRY_RUN=1 \
		SYSTEM_GAMING_GAMESCOPE=/bin/true \
		SYSTEM_GAMING_STEAM=/bin/true \
		"$@" \
		bash "$SESSION"
}

command=$(run_session \
	SYSTEM_GAMING_OUTPUT=DP-1,eDP-1 \
	SYSTEM_GAMING_GPU=1002:73ef \
	SYSTEM_GAMING_HDR=1)

[[ $command == *'--steam'* ]]
[[ $command == *'--backend drm'* ]]
[[ $command == *'--xwayland-count 2'* ]]
[[ $command == *'--adaptive-sync'* ]]
[[ $command == *'--mangoapp'* ]]
[[ $command == *'--prefer-output DP-1\,eDP-1'* ]]
[[ $command == *'--prefer-vk-device 1002:73ef'* ]]
[[ $command == *'--hdr-enabled'* ]]
[[ $command == *'-- /bin/true -gamepadui'* ]]

command=$(run_session \
	SYSTEM_GAMING_OUTPUT=auto \
	SYSTEM_GAMING_GPU=auto \
	SYSTEM_GAMING_HDR=0)
[[ $command != *'--prefer-vk-device'* ]]
[[ $command != *'--hdr-enabled'* ]]

printf 'SYSTEM_GAMING_GPU=1002:73ef\n' >"$TEST_DIRECTORY/system.conf"
printf 'SYSTEM_GAMING_OUTPUT=HDMI-A-1\nSYSTEM_GAMING_HDR=1\n' \
	>"$TEST_DIRECTORY/user.conf"
command=$(run_session \
	SYSTEM_GAMING_SYSTEM_CONFIG="$TEST_DIRECTORY/system.conf" \
	SYSTEM_GAMING_USER_CONFIG="$TEST_DIRECTORY/user.conf")
[[ $command == *'--prefer-output HDMI-A-1'* ]]
[[ $command == *'--prefer-vk-device 1002:73ef'* ]]
[[ $command == *'--hdr-enabled'* ]]

if run_session SYSTEM_GAMING_HDR=yes >/dev/null 2>&1; then
	printf 'Gaming session accepted an invalid HDR value\n' >&2
	exit 1
fi

file=$(mktemp "$TEST_DIRECTORY/config.XXXXXX")
printf 'UNKNOWN_SETTING=1\n' >"$file"
if env \
	HOME="$TEST_DIRECTORY" \
	SYSTEM_GAMING_SYSTEM_CONFIG="$file" \
	SYSTEM_GAMING_USER_CONFIG="$TEST_DIRECTORY/empty.conf" \
	SYSTEM_GAMING_DRY_RUN=1 \
	bash "$SESSION" >/dev/null 2>&1
then
	printf 'Gaming session accepted an unknown configuration key\n' >&2
	exit 1
fi

ledger="$PROJECT_ROOT/modules/gaming/upstream-research.yaml"
commit_count=$(rg -c '^    commit: [0-9a-f]{40}$' "$ledger")
review_count=$(rg -c '^    reviewed_at: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$ledger")
((commit_count > 0 && commit_count == review_count))

printf 'gaming session and research ledger: ok\n'
