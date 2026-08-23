#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

command -v qemu-img >/dev/null || {
	echo 'qemu-img is required' >&2
	exit 1
}
require_vm_file "$OVMF_CODE"
require_vm_file "$OVMF_VARS_TEMPLATE"

mkdir -p "$(dirname -- "$VM_DISK")" "$(dirname -- "$VM_VARS")"

if [[ ! -f $VM_DISK ]]; then
	qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"
else
	echo "Keeping existing disk: $VM_DISK"
fi

if [[ ! -f $VM_VARS ]]; then
	cp "$OVMF_VARS_TEMPLATE" "$VM_VARS"
else
	echo "Keeping existing UEFI variables: $VM_VARS"
fi
