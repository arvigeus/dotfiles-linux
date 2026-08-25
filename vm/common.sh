#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_FILE=${CONFIG_FILE:-"$PROJECT_ROOT/.vm.env"}
[[ -f $CONFIG_FILE ]] || {
	echo "Missing $CONFIG_FILE; copy .vm.env.example to .vm.env" >&2
	exit 1
}

set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a

HOSTNAME=${HOSTNAME:-system-vm}

absolute_path() {
	local path=$1
	if [[ $path == /* ]]; then
		printf '%s\n' "$path"
	else
		printf '%s/%s\n' "$PROJECT_ROOT" "$path"
	fi
}

VM_DISK=$(absolute_path "${VM_DISK:-vm/${HOSTNAME}.qcow2}")
VM_DISK_SIZE=${VM_DISK_SIZE:-24G}
VM_VARS=$(absolute_path "${VM_VARS:-vm/OVMF_VARS.fd}")
if [[ -n ${SOURCE_ISO:-} ]]; then
	SOURCE_ISO=$(absolute_path "$SOURCE_ISO")
fi
VM_MEMORY_MB=${VM_MEMORY_MB:-2048}
VM_CPUS=${VM_CPUS:-2}

first_existing_file() {
	local candidate
	for candidate in "$@"; do
		[[ -f $candidate ]] && {
			printf '%s\n' "$candidate"
			return
		}
	done
	printf '%s\n' "${1:-}"
}

OVMF_CODE=${OVMF_CODE:-$(first_existing_file \
	/usr/share/edk2/x64/OVMF_CODE.4m.fd \
	/usr/share/OVMF/OVMF_CODE_4M.fd \
	/usr/share/OVMF/OVMF_CODE.fd)}
OVMF_VARS_TEMPLATE=${OVMF_VARS_TEMPLATE:-$(first_existing_file \
	/usr/share/edk2/x64/OVMF_VARS.4m.fd \
	/usr/share/OVMF/OVMF_VARS_4M.fd \
	/usr/share/OVMF/OVMF_VARS.fd)}

require_vm_file() {
	[[ -f $1 ]] || {
		echo "Missing required file: $1" >&2
		exit 1
	}
}

qemu_acceleration() {
	if [[ -r /dev/kvm && -w /dev/kvm ]]; then
		printf 'kvm\n'
	else
		printf 'tcg\n'
	fi
}

qemu_cpu() {
	if [[ $(qemu_acceleration) == kvm ]]; then
		printf 'host\n'
	else
		printf 'max\n'
	fi
}
