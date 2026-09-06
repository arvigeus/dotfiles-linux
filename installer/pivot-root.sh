#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${1:-} == --detach-old-root ]]; then
	shift
	# pivot_root(8)'s ". ." form stacks the old root on /. Detach that
	# inaccessible mount after chroot has selected the new root.
	umount --lazy /
	exec "$@"
fi

target_root=${1:?target root required}
helper_path=${2:?target helper path required}
shift 2

# Do not let propagation from the private namespace affect the live system.
mount --make-rprivate /
# pivot_root requires the new root to be a mount point. Clone its nested
# mounts too: /run/system contains this helper and the module sources, while
# /dev, /proc, and /sys provide the candidate's live hardware view.
mount --rbind "$target_root" "$target_root"
cd "$target_root"
pivot_root . .

exec chroot . /bin/bash "$helper_path" \
	--detach-old-root "$@"
