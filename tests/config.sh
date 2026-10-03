#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$PROJECT_ROOT/installer/common.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
# Invalid input re-prompts, Enter uses the default, EOF fails.
exec 3<<<$'garbage\n0\n3\n2'
prompt_select chosen Desktop 1 plasma hyprland
[[ $chosen == hyprland ]]
exec 3<<<''
prompt_select chosen Desktop 1 plasma hyprland
[[ $chosen == plasma ]]
if (
	exec 3</dev/null
	prompt_select chosen Desktop 1 plasma hyprland
) 2>/dev/null; then
	exit 1
fi
SYSTEM_DESKTOP=plasma # the explicit CLI selection wins over the environment
bootstrap_options --disk /dev/vda --host-profile zephyrus --hostname workstation --desktop hyprland --username tester --timezone UTC --locale en_US.UTF-8 --keymap us
[[ $SYSTEM_DESKTOP == hyprland && $SYSTEM_HOST_PROFILE == zephyrus && $SYSTEM_HOSTNAME == workstation ]]
bootstrap_options --non-interactive
[[ $SYSTEM_NONINTERACTIVE == true ]]
(
	SYSTEM_HOST_PROFILE=work_station SYSTEM_HOSTNAME=
	prompt_bootstrap_config
	[[ $HOST_PROFILE == work_station && $HOSTNAME == work-station && $DESKTOP == hyprland ]]
)
bootstrap_value USERNAME User user
[[ $USERNAME == tester ]]
if (bootstrap_options --desktop) 2>/dev/null; then exit 1; fi
DISTRO=arch DESKTOP=hyprland validate_desktop
DISTRO=fedora DESKTOP=plasma validate_desktop
if (DISTRO=fedora DESKTOP=hyprland validate_desktop) 2>/dev/null; then exit 1; fi
if (DISTRO=arch DESKTOP=invalid validate_desktop) 2>/dev/null; then exit 1; fi
# Installed configuration round-trips independent hostname/profile and desktop.
TARGET_ROOT="$TEST_ROOT/root" SYSTEM_CONFIG=/etc/system/config
DISK=/dev/vda HOSTNAME=workstation HOST_PROFILE=zephyrus DESKTOP=hyprland
USERNAME=tester TIMEZONE=UTC LOCALE=en_US.UTF-8 KEYMAP=us
write_system_config
unset DESKTOP HOST_PROFILE
source "$TARGET_ROOT$SYSTEM_CONFIG"
[[ $DESKTOP == hyprland && $HOST_PROFILE == zephyrus && $HOSTNAME == workstation ]]
[[ $(stat -c %a "$TARGET_ROOT$SYSTEM_CONFIG") == 644 ]]
# Destructive confirmation must require an exact path, even for blank input.
if (confirm_destroy_disk false <<<'') 2>/dev/null; then exit 1; fi
if (confirm_destroy_disk false <<<'/dev/vdb') 2>/dev/null; then exit 1; fi
confirm_destroy_disk false <<<'/dev/vda'
printf 'installer configuration: ok\n'
