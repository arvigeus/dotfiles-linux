# system

A Bash-managed Arch Linux or Fedora system with two mutable Btrfs root
subvolumes, persistent home, LUKS2 encryption, and direct UEFI unified kernel
images.

This is an experimental personal installer, not a production-ready general
installer. Test it in a disposable VM before pointing it at real hardware.

## Model

```text
EFI System Partition
└── EFI/Linux/system-{a,b}.efi

LUKS2
└── Btrfs
    ├── @root-a       mutable root
    ├── @root-b       mutable root
    └── @home         persistent home
```

Bootstrap from an Arch ISO to install Arch, or from a Fedora ISO to install
Fedora. Both slots always remain that distribution.

The active slot is an ordinary mutable Linux system: update it, install things
manually, and accept drift whenever useful. `rebuild.sh` provides the clean
reconciliation path. It constructs the inactive slot from the repository,
selects it for the next boot, then asks whether to reboot immediately. Declining
only postpones the switch.

The exact architectural contract is in [docs/design.md](docs/design.md).

## Bootstrap

Requirements:

- UEFI x86-64;
- installation media matching the desired distro;
- internet access;
- the native storage, package, UKI, and SELinux tools documented for the
  backends;
- a disk that may be completely erased.

From a root shell in the live environment:

```bash
git clone <this-repository-url> system
cd system
./bootstrap.sh
```

The script detects Arch or Fedora and interactively asks for the target disk,
hostname, username, timezone, locale, and keymap. It displays the disk again and
requires exact destructive confirmation unless `--yes` was explicitly passed.
It also prompts for LUKS and login passwords through the native tools.

No installer `.env` is used. Non-secret installation answers are retained at
`/etc/system/config` for future rebuilds.

## Clean rebuild

Run from the installed system using a current clone of this repository:

```bash
sudo ./rebuild.sh
```

The running slot is never rewritten. The inactive root is recreated, all
modules run, selected machine state is preserved, home defaults are reconciled,
and the new UKI is placed first in UEFI boot order. The old slot remains in the
firmware menu as a manual fallback.

There is currently no automatic boot-health rollback. A successful build and
UKI generation do not prove that the new slot boots, so keep firmware access
available while testing.

## Modules

Every `modules/**/*.sh` file executes in lexical order inside the candidate.
Modules are isolated trusted-root Bash scripts and must guard themselves when
they only apply to a distro or piece of hardware.

```bash
source "$SETUP_ROOT/lib/module.sh"

packages=(
    nano
    fedora:fedora-only-package
    arch:aur/arch-only-aur-package
    flathub/org.example.Application
)

pkg_install "${packages[@]}"
```

Package source plugins are demand-driven:

```text
pm/arch/pacman.sh       Arch native manager and its configuration
pm/fedora/dnf.sh        Fedora native manager and its configuration
pm/flathub.sh           shared system Flatpak source
pm/npm.sh               shared system-wide npm source
pm/arch/aur.sh          Arch-only AUR source
pm/fedora/claude.sh     Fedora-only Anthropic RPM source
pm/fedora/openai.sh     Fedora-only official ChatGPT bootstrap source
pm/fedora/terra.sh      Fedora-only Terra source
```

If no selected declaration references Flathub, Flatpak and Flathub are not
installed or enabled. The same rule applies to every plugin. See the design
contract for the exact grammar and plugin API.

Local package recipes are used only when an enabled repository or the AUR does
not already carry the package. They live in `packages/<distro>/<name>/`:
`arch:pkgbuild/<name>` builds `packages/arch/<name>/PKGBUILD`, while
`fedora:rpmspec/<name>` builds `packages/fedora/<name>/<name>.spec` after
verifying the downloaded sources against `sources.sha256`. Bootstrap and
rebuild resolve these local recipes to the latest stable release (or latest
default-branch commit) in an ephemeral copy before modules run.

## File declarations

```bash
file_write -m 0600 -o root -g root /etc/example.conf <<'EOF'
key=value
EOF
```

`file_append` accepts the same metadata options. New files default to
`0644 root:root`; unspecified metadata is retained when replacing an existing
file.

## VM testing

The helper scripts require QEMU and OVMF on the host:

```bash
cp .vm.env.example .vm.env
$EDITOR .vm.env
./vm/create.sh
./vm/run-installer.sh
```

The repository is exposed read-only as the QEMU 9p share `setup`. In the live
guest:

```bash
sudo -i
mkdir -p /root/setup
mount -t 9p -o trans=virtio,version=9p2000.L setup /root/setup
cd /root/setup
./bootstrap.sh
poweroff
```

Then start the installed disk with `./vm/run.sh`. Keep separate VM disks and
OVMF variable files when testing Arch and Fedora.

Fedora-specific backend assumptions and validation points are documented in
[docs/fedora.md](docs/fedora.md). Gaming-session details are in
[modules/gaming/README.md](modules/gaming/README.md).

## Current limits

- one disk, one login user, fixed UID/GID 1000, and the fixed layout above;
- no cross-distribution build or migration;
- no Secure Boot setup;
- no automatic boot rollback;
- home reconciliation is best effort rather than globally atomic;
- every rebuild downloads and installs a complete native base;
- Fedora boot behavior still requires end-to-end VM validation.
