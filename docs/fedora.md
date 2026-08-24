# Fedora backend notes

Fedora support builds a conventional mutable Fedora installation from Fedora
live media. It does not use bootc, containers, GRUB, or systemd-boot.

## Backend operations

The backend uses current DNF5 installroot behavior:

```text
dnf --installroot=TARGET --releasever=VERSION --use-host-config install ...
```

DNF5 documents that a new empty installroot has no RPM database from which to
derive `$releasever` and no repository files. The backend therefore takes
`VERSION_ID` from the detected Fedora `/etc/os-release`, passes it explicitly,
and requests the live host's repository configuration. This is native Fedora
to Fedora only.

The package set provides the mutable base, kernel and modules, firmware, dracut,
Btrfs/LUKS tools, NetworkManager, DNF/RPM, sudo, jq, Mike Farah-compatible `yq`,
targeted SELinux policy, policy tools, `systemd-boot-unsigned` for the EFI stub,
and `systemd-ukify`. It deliberately does not install a graphical environment.

## UKI

For the newest installed kernel, the backend invokes dracut with:

- `--uefi --ukify` and an explicit kernel image;
- `--no-hostonly` for a generic image;
- explicit crypt, Btrfs, systemd-initrd, and i18n modules;
- an embedded command line naming the LUKS UUID and mapper;
- `rootfstype=btrfs rootflags=subvol=@root-a|@root-b`;
- `selinux=1 enforcing=1`.

The output is atomically placed at
`EFI/Linux/dotfiles-a.efi` or `dotfiles-b.efi` and is registered
directly with UEFI.

The installed mutable root also contains a `kernel-install` plugin and
`dotfiles-refresh-uki` helper. A native kernel installation regenerates the UKI
for the currently mounted A/B slot, and Steam's native updater invokes the
helper once more after a DNF transaction as a fallback. Neither path modifies
the inactive slot. The initial clean build continues to use the offline backend
path above.

## SELinux

Provisioning can create files through DNF, static overlays, modules, preserved
state, and home reconciliation. After all of those writes, Fedora's native
`setfiles` labels the candidate root and mounted persistent home using the
candidate's `selinux-policy-targeted` file contexts. Pseudo-filesystems,
private `/run`, and the FAT ESP are excluded.

No `/.autorelabel` marker is left because the offline full-tree labelling is
intended to make it unnecessary. Thus normal first boot should remain enforcing
and should not incur a full relabel delay. If recovery work requires
`/.autorelabel`, expect a long first boot; Fedora/Red Hat guidance recommends a
permissive relabel boot (commonly temporary `enforcing=0`) when existing labels
cannot be trusted. The normal slot UKI intentionally does not embed permissive
mode.

## Unvalidated assumptions

This implementation has been source-reviewed but **has not booted Fedora in
this development environment**. Validate these assumptions in a disposable VM:

1. The selected current Fedora live ISO contains DNF5, `setfiles`, `sgdisk`,
   `mkfs.btrfs`, cryptsetup, efibootmgr, and other required native tools. Some
   Fedora live variants may omit storage utilities and are unsuitable without
   creating appropriate installation media.
2. DNF5 `--use-host-config` exposes enabled Fedora repositories to the empty
   installroot and all listed package names remain available for that Fedora
   release.
3. Fedora's `systemd-boot-unsigned` installs the EFI stub expected by the
   installed dracut/ukify versions, without configuring systemd-boot itself.
4. The installed kernel is available at `/usr/lib/modules/VERSION/vmlinuz` or
   `/boot/vmlinuz-VERSION`.
5. Current dracut accepts `--uefi --ukify`, the listed module names, explicit
   output path and kernel version, and honors the embedded
   `rd.luks.name=UUID=cryptroot` mapping.
6. The generic UKI contains virtio/NVMe/storage, keyboard, crypto, and Btrfs
   support needed before root mount on intended hardware.
7. `setfiles -r TARGET` with the candidate policy correctly labels both the
   candidate Btrfs root and mounted persistent home while excluded mountpoints
   are not traversed.
8. Fedora boots enforcing without `/.autorelabel`, NetworkManager starts from
   the minimal package set, and the copied resolver file is accepted.
9. Kernel package scriptlets in the installroot do not require a configured
   GRUB/systemd-boot boot manager; the explicitly generated UKI is sufficient.
10. Fedora kernel transactions invoke the installed `kernel-install` plugin,
    and its dracut command atomically replaces only the running slot's UKI.

Use the four exact manual validation flows in the project README. Do not treat
successful UKI generation alone as proof that unlock, root selection, SELinux,
or firmware fallback works.

## Sources consulted

- DNF5 installroot documentation:
  <https://dnf5.readthedocs.io/en/stable/misc/installroot.7.html>
- dracut command documentation:
  <https://man7.org/linux/man-pages/man8/dracut.8.html>
- Fedora `systemd-boot-unsigned` package:
  <https://packages.fedoraproject.org/pkgs/systemd/systemd-boot-unsigned/>
- Fedora `yq` package: <https://packages.fedoraproject.org/pkgs/yq/yq/>
- Red Hat SELinux relabel guidance:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_selinux/changing-selinux-states-and-modes>
