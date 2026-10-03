#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

command -v qemu-system-x86_64 >/dev/null || {
	echo 'qemu-system-x86_64 is required' >&2
	exit 1
}
[[ -n ${SOURCE_ISO:-} ]] || {
	echo 'Set SOURCE_ISO in .vm.env' >&2
	exit 1
}
require_vm_file "$SOURCE_ISO"
require_vm_file "$OVMF_CODE"
require_vm_file "$VM_VARS"
require_vm_file "$VM_DISK"

exec qemu-system-x86_64 \
	-name "$HOSTNAME-installer" \
	-machine "q35,accel=$(qemu_acceleration)" \
	-cpu "$(qemu_cpu)" \
	-smp "$VM_CPUS" \
	-m "$VM_MEMORY_MB" \
	-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
	-drive "if=pflash,format=raw,file=$VM_VARS" \
	-drive "if=virtio,format=qcow2,file=$VM_DISK" \
	-cdrom "$SOURCE_ISO" \
	-boot order=d,menu=on \
	-nic "$VM_NETWORK" \
	"${VM_QEMU_ARGS[@]}" \
	-virtfs "local,path=$PROJECT_ROOT,mount_tag=setup,security_model=none,readonly=on"
