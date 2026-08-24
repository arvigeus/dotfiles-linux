# dotfiles Arch/Fedora PoC

An experimental, deliberately small native Arch Linux or Fedora builder with
clean Btrfs A/B roots, persistent home, LUKS2 encryption, direct UEFI UKIs, and
recursively discovered Bash modules.

This is a proof of concept, not a production installer. Test it in a disposable
VM before considering real hardware.

## Native-distribution model

Distribution selection is not configuration:

```text
Arch installation ISO -> Arch installation
Fedora live ISO        -> Fedora installation
Arch installed root    -> Arch clean rebuild
Fedora installed root  -> Fedora clean rebuild
```

The scripts read `/etc/os-release` and accept only `ID=arch` or `ID=fedora`.
They export `DISTRO=arch|fedora` and `PACKAGE_MANAGER=pacman|dnf`. Values from
the environment or `.env` cannot override detection. Cross-distribution builds
and migrations are unsupported, so both A/B slots always contain generations
of the running distribution.

The disk model is shared:

```text
EFI System Partition (FAT32)
└── EFI/Linux/
    ├── dotfiles-a.efi
    └── dotfiles-b.efi

LUKS2
└── Btrfs
    ├── @root-a
    ├── @root-b
    └── @home
```

`bootstrap.sh` destructively creates the layout and installs root A.
`rebuild.sh` detects the running slot, constructs the inactive slot from
nothing, and puts its UKI first in UEFI `BootOrder`. The previous root and UKI
remain manually bootable from firmware. There is no GRUB or systemd-boot;
firmware launches each UKI directly. Secure Boot is outside this PoC.

## Requirements

Bootstrap must run in UEFI mode from installation media for the distribution
being installed. Use an Arch installation ISO for Arch, or current Fedora live
media with DNF5 and the required native storage/SELinux utilities for Fedora.
The target needs internet access. Rebuild runs only from an installed root of
the same distribution.

Arch uses `pacstrap`, Pacman, and mkinitcpio. Fedora uses DNF5 `--installroot`,
RPM/DNF, dracut/ukify, and native SELinux labelling. The common chroot helper
mounts `/dev` (including `/dev/pts`), `/proc`, `/sys`, and a private `/run`, and
copies live DNS configuration into the candidate. See [Fedora backend
notes](docs/fedora.md) for current assumptions and SELinux behavior.

For VM testing, the host needs QEMU and OVMF. This project does not install host
dependencies.

## Configuration

```bash
cp .env.example .env
$EDITOR .env
```

`.env` is sourced as Bash and excluded from Git. It contains only disk,
hostname, user, timezone, keymap, and VM ISO choices. It deliberately has no
distribution option. CPU microcode is detected automatically. Passwords are
prompted rather than stored.

The fixed layout uses ESP partition 1, LUKS partition 2, UID/GID 1000, and the
subvolume names shown above. The example disk is QEMU's `/dev/vda`.
**`bootstrap.sh` erases `DISK`; verify it first.**

## Manual VM validation

Set either an Arch or Fedora ISO in `.env`:

```dotenv
SOURCE_ISO=/absolute/path/to/installation.iso
```

Reset the disposable disk and UEFI variables, create them, then boot the ISO:

```bash
bash -c 'source vm/common.sh; rm -f -- "$VM_DISK" "$VM_VARS"'
./vm/create.sh
./vm/run-installer.sh
```

The project is exposed read-only as the QEMU 9p share `setup`. OVMF state is
persistent, so direct boot entries and their order survive VM restarts.

### 1. Fedora ISO -> Fedora bootstrap -> Fedora boot

In the Fedora live environment, open a root shell and mount the share (install
9p-capable Fedora live media is required):

```bash
sudo -i
mkdir -p /root/setup
mount -t 9p -o trans=virtio,version=9p2000.L setup /root/setup
cd /root/setup
./bootstrap.sh --yes
poweroff
```

Remove the ISO by starting `./vm/run.sh`. Enter the LUKS and login passwords,
confirm `/etc/os-release` says Fedora, `/` is `@root-a`, networking works,
SELinux is enforcing, and the active UKI is `dotfiles-a.efi`.

### 2. Fedora running -> clean rebuild -> opposite slot

Inside the installed Fedora VM:

```bash
sudo mkdir -p /mnt/setup
sudo mount -t 9p -o trans=virtio,version=9p2000.L setup /mnt/setup
cd /mnt/setup
sudo ./rebuild.sh
sudo reboot
```

Confirm Fedora boots from `@root-b`, SELinux remains enforcing, persistent home
is intact, and firmware can still manually boot slot A.

### 3. Arch ISO -> Arch bootstrap -> Arch boot

Change `SOURCE_ISO` to an Arch installation ISO, then create a separate clean
disk and OVMF state:

```bash
bash -c 'source vm/common.sh; rm -f -- "$VM_DISK" "$VM_VARS"'
./vm/create.sh
./vm/run-installer.sh
```

At the Arch ISO:

```bash
mkdir -p /root/setup
mount -t 9p -o trans=virtio,version=9p2000.L setup /root/setup
cd /root/setup
./bootstrap.sh --yes
poweroff
```

Start `./vm/run.sh`; confirm `/etc/os-release` says Arch, `/` is `@root-a`, and
slot A boots directly.

### 4. Arch running -> clean rebuild -> opposite slot

Mount the share and run:

```bash
sudo mkdir -p /mnt/setup
sudo mount -t 9p -o trans=virtio,version=9p2000.L setup /mnt/setup
cd /mnt/setup
sudo ./rebuild.sh
sudo reboot
```

Confirm Arch boots from `@root-b`, home persists, and slot A remains manually
bootable.

These four flows have not been run on this resource-constrained development
machine.

## Modules

Every `*.sh` below `modules/`, at any depth, runs in lexical order in an
isolated Bash process inside the candidate. Static `files/` are copied first.
Modules are trusted root code and should be independent.

Modules receive:

```text
HOME=/etc/skel
XDG_CONFIG_HOME=/etc/skel/.config
XDG_DATA_HOME=/etc/skel/.local/share
XDG_STATE_HOME=/etc/skel/.local/state
XDG_CACHE_HOME=/tmp/dotfiles-cache
SETUP_ROOT
MODULE_DIR
USERNAME
USER_UID
USER_GID
DISTRO
PACKAGE_MANAGER
PROJECT_ID=dotfiles
PRESERVE_REQUESTS_FILE
```

Source the common helpers and use the repository-independent package interface:

```bash
source "$SETUP_ROOT/lib/module.sh"
packages=(
 nano
 fedora:fedora-only-package
 arch:aur/arch-only-aur-package
 flathub/org.example.Application
)
pkg_install "${packages[@]}"
pkg_is_installed nano
```

Package specifications have four forms:

```text
name                    current distro's native package
<distro>:<name>         native package selected only for that distro
<repo>/<name>           repository package on every distro that provides it
<distro>:<repo>/<name>  repository package selected only for that distro
```

Repository lookup checks `distros/$DISTRO/repos/<repo>.sh` first and then
`distros/common/repos/<repo>.sh`. Missing repositories are errors; there are no
placeholder plugins or symlinks. This makes `flathub/...` portable, while an
Arch-only AUR package is explicitly written as `arch:aur/...`. Each plugin owns
repository setup and delegates installation to its package manager. Distro
backends live at `distros/<distro>/distro.sh`.

`pkg_from_source build_function dep...` installs only requested build
dependencies that are absent, runs the function, and attempts to remove only
those added dependencies even after failure.

Other helpers include `file_write`, `file_append`, `file_install_tree`,
`github_latest_tag`, `github_latest_download`, `github_download`,
`github_raw_url`, and `github_read_file`. `preserve_path /absolute/path...`
requests that matching machine-local state be copied from the active root after
all modules finish; globs are supported and missing paths are ignored. Flatpak
repository plugins install directly into the candidate's system installation.
`flatpak_alias` remains available from `lib/flatpak.sh` when a module needs a
command alias. The imported module inventory,
distribution limitations, and disabled runtime-only work are documented in
[docs/ported-modules.md](docs/ported-modules.md).

### KDE and gaming sessions

The desktop module installs a small Plasma Wayland environment with KDE's
Plasma Login Manager. The gaming module adds selectable **SteamOS (gamescope)**
and **Steam Big Picture Plus** sessions while keeping manual login. Steam's OS
update action performs a native in-place update of the active root; clean A/B
rebuilds remain available whenever a fresh generation is wanted. Laptop-specific
RX 6800S/Cardwire behavior, component provenance, repository boundaries, and
optional InputPlumber and PowerStation activation are covered in
[docs/gaming-session.md](docs/gaming-session.md).

## Home and preserved state

Persistent home is mounted only after provisioning succeeds. The active and
candidate `/etc/skel` trees are reconciled into `/home/$USERNAME`. JSON, YAML,
TOML, and INI have structured strategies; other files replace the prior
skeleton value. Candidate changes win, unchanged user values remain, and
replaced files are backed up below
`~/.local/state/dotfiles/backups/`. `home_strategy` provides per-path
overrides. JSON uses `jq`; YAML/TOML use the distribution's yq package;
`crudini` is optional.

Modules use `preserve_path` to request selected machine identity, network
credentials, Bluetooth pairings, and SSH host keys from the active root. The
requests are copied after all modules finish. The login password hash is copied
separately. There are no migration modes or generation databases.

## Limitations

- UEFI x86-64, one disk, one login user, and a fixed partition layout only.
- No cross-distribution install, rebuild, or migration.
- Firmware behavior for custom direct-UKI entries varies.
- No automatic boot-health rollback.
- Home reconciliation is best effort and not globally atomic.
- Modules are trusted root code; conflicting writes are an authoring error.
- Every rebuild downloads and installs a complete base.
- Fedora support is source-reviewed but not runtime-validated; see
  [docs/fedora.md](docs/fedora.md).

## Real-hardware warning

Do not point this PoC at a real disk until bootstrap, direct UKI boot, rebuild,
home reconciliation, SELinux behavior, and firmware fallback have all been
validated in disposable VMs for the chosen distribution.
