# Design notes

## Distribution boundary

`load_config` discards any inherited or configured distribution values, reads
`/etc/os-release`, and exports exactly one native backend:

- `lib/distro/arch.sh`: pacstrap/Pacman, Arch base packages and locale setup,
  CPU microcode selection, and mkinitcpio UKIs.
- `lib/distro/fedora.sh`: DNF5 installroot/RPM operations, Fedora base packages,
  dracut/ukify UKIs, and SELinux labelling.

Common code owns partitioning, LUKS2, Btrfs, slots, mounts, credentials, static
files, module execution, persistent home, UEFI entries, and reconciliation.
The fixed, non-configurable `PROJECT_ID=dotfiles` namespaces project-owned
runtime, policy, backup, preset, and UKI paths; it is deliberately independent
of the machine hostname. There is intentionally no distribution configuration
or cross-build path.

## Module independence and selection

Recursive lexical discovery provides deterministic logs, not a dependency API.
Modules run in isolated Bash processes and must install their own requirements,
source their own reusable helpers, and configure any required third-party
repository themselves. Adding an ordered `modules.conf` would hide dependencies
and is intentionally avoided.

Machine-specific modules use native hardware guards instead: CPU vendor, PCI
vendor, DMI identity, or USB vendor. Broader workstation/persona selection can
use a separate tree through `MODULES_PATH`, but selection must not supply shared
shell state or execution-order dependencies.

## Target execution

`target_chroot` uses plain `chroot` only after preparing a complete execution
environment. `/dev` is recursively bound (including `/dev/pts`), `/proc` is a
fresh proc mount, `/sys` is recursively bound, and `/run` is a private tmpfs.
Live `/etc/resolv.conf` content is copied into the target for DNS. Every mount is
registered in the existing reverse-order cleanup stack, including nested module
and old-skeleton bind mounts.

## Rebuild transaction

1. Detect the distribution of the running root and select its native backend.
2. Identify the mounted Btrfs root subvolume.
3. Delete and recreate only the inactive root subvolume.
4. Mount the inactive root and shared ESP; leave home unmounted.
5. Install a native clean base and create the configured login account.
6. Copy the common static `files/` overlay into the candidate.
7. Run every recursive Bash module with `HOME=/etc/skel`, `DISTRO`, and
   `PACKAGE_MANAGER`.
8. Copy machine-local state requested declaratively by modules from the active root.
9. Generate a slot-specific native UKI at a temporary ESP path and rename it.
10. Mount persistent home and reconcile active versus candidate skeletons.
11. On Fedora, relabel the complete candidate and persistent home with the
    candidate policy, excluding pseudo-filesystems and the FAT ESP.
12. Put the candidate direct UKI first in UEFI `BootOrder`.

A failure before step 10 does not touch home. A failure before step 12 does not
change firmware ordering. The active root and UKI are never modified. Cleanup
unmounts all tracked target execution mounts after either success or failure.

## UKI boundary

Arch retains the existing systemd-based mkinitcpio hooks, `sd-encrypt`, Btrfs
rootflags, and microcode autodetection. A project Pacman hook regenerates the
currently installed slot's direct UKI after native kernel upgrades.

Fedora uses a generic dracut image with its `crypt`, `btrfs`, systemd initrd,
i18n/keyboard, and kernel-module support. Dracut/ukify embeds the selected
Fedora kernel, initramfs, and slot-specific command line in the existing
`EFI/Linux/dotfiles-{a,b}.efi` convention. Firmware launches it directly;
no systemd-boot or GRUB package is configured as a boot manager. Its installed
`kernel-install` plugin provides the equivalent running-slot refresh for native
kernel upgrades.

## SELinux

Fedora provisioning remains SELinux-aware. After static files, modules,
preserved state, and home reconciliation, host `setfiles` applies the
candidate's targeted policy to the candidate root and mounted persistent home.
`/dev`, `/proc`, `/sys`, private `/run`, and the FAT ESP are excluded. The UKI
keeps `selinux=1 enforcing=1`.

Because the complete offline tree is labelled before activation, the backend
does not create `/.autorelabel`; therefore no deliberate first-boot relabel
delay is expected. If manual recovery creates `/.autorelabel`, Fedora may spend
substantial time relabelling at the next boot, and Fedora guidance recommends a
permissive relabel boot when labels are not already trustworthy.

## Intentional non-goals

This is not a reproducible build, package-state reconciler, backup system,
distribution migration tool, cross-bootstrap system, or unattended fleet
installer. Mutable changes to the active root are discarded by the next clean
build unless represented by a module or requested through `preserve_path`.
