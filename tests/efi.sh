#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=installer/efi.sh
source "$PROJECT_ROOT/installer/efi.sh"

# Keep emitting after the matching entry. An early awk exit closes the pipe,
# causing this producer to fail with SIGPIPE when pipefail is enabled.
efibootmgr() {
	printf '%s\n' 'Boot0001* system-a'
	seq 1 10000 | sed 's/.*/BootFFFF* unrelated/'
}

[[ $(boot_number_for_label system-a) == 0001 ]]
printf 'UEFI entry parsing: ok\n'
