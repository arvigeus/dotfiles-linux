# system

A Bash-managed Arch Linux or Fedora system with two mutable Btrfs root
subvolumes, persistent home, LUKS2 encryption, and direct UEFI unified kernel
images.

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

Bootstrap from the target distribution’s installation media. Each slot remains
associated with the distribution installed into it.

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

The script detects the distribution and interactively asks for the target disk,
host profile, desktop, hostname, username, timezone, locale, and keymap.
Disk/profile/desktop use numbered menus; other answers have sensible defaults.
See [desktop profiles](docs/desktops.md) for CLI/environment overrides.
It also prompts for LUKS and login passwords through the native tools.

No installer `.env` is used. Non-secret installation answers are retained at
`/etc/system/config` for future rebuilds.

## Clean rebuild

Run from the installed system using a current clone of this repository:

```bash
sudo ./rebuild.sh
```

Use `sudo ./rebuild.sh --healthchecks` to run selected modules' optional online
health checks after application. They are excluded from the default critical
path.

The running slot is never rewritten. The inactive root is recreated, all
modules run, selected machine state is preserved, home defaults are reconciled,
and the new UKI is placed first in UEFI boot order. The old slot remains in the
firmware menu as a manual fallback.

There is currently no automatic boot-health rollback. A successful build and
UKI generation do not prove that the new slot boots, so keep firmware access
available while testing.

## Modules

`hosts/<HOST_PROFILE>.sh` explicitly selects modules. Aggregate modules contain an
ordered `members` array; selecting `gaming` expands its declared children,
while selecting `gaming/steam` installs only Steam. Filesystem discovery is not
part of execution.

```bash
source "$SETUP_ROOT/lib/module.sh"

packages=(
    nano
    fedora:fedora-only-package
    arch:aur/arch-only-aur-package
    flathub/org.example.Application
)

module_apply() {
    # Idempotent configuration, after packages are installed.
    :
}

module_entrypoint "$@"
```

Planning, source preparation, grouped package installation, and module
application are separate deterministic phases. A module can co-locate an
automatic root overlay in `files/`, a one-module package source in
`sources/<distro>/`, and native build recipes in `packages/<distro>/`.
Conflicting paths between selected `files/` overlays and symlinks inside an
overlay are rejected during planning.

Package source plugins are demand-driven:

```text
sources/arch/pacman.sh       Arch native manager and its configuration
sources/fedora/dnf.sh        Fedora native manager and its configuration
sources/arch/alhp.sh         Arch x86-64-v3 optimized overlay (CPU-gated)
sources/flathub.sh           shared system Flatpak source
sources/npm.sh               shared system-wide npm source
sources/arch/aur.sh          Arch-only AUR source
sources/fedora/terra.sh      Fedora-only Terra source
```

If no selected declaration references Flathub, Flatpak and Flathub are not
installed or enabled. The same rule applies to every source. Global overlays
that do not correspond to one package are still explicit module declarations;
for example `base/package-sources` declares `sources=(arch:alhp)`.

Local package recipes are used only when an enabled repository or the AUR does
not already carry the package. They live beside their owning module under
`packages/<distro>/<name>/`. Only recipes belonging to selected modules are
copied and resolved automatically before package installation on both
`bootstrap.sh` and `rebuild.sh`. Every applicable `update.sh` runs against a
temporary copy; release-based recipes resolve the latest stable release and
reject drafts/prereleases. Resolution failures stop provisioning instead of
using the tracked snapshot. See [recipe maintenance](packages/README.md),
[the module contract](modules/README.md) and
[the design document](docs/design.md) for the exact rules.

## File declarations

```bash
file_write -m 0600 -o root -g root /etc/example.conf <<'EOF'
key=value
EOF
```

`file_append` accepts the same metadata options. New files default to
`0644 root:root`; unspecified metadata is retained when replacing an existing
file.

## Failure diagnosis

Major installer phases and every module transition are logged before they run.
The latest phase is written to `/run/system-provision-state` and, after the
candidate root is mounted, `/var/lib/system/provision-state` in that candidate.
On failure the cleanup handler prints the last recorded phase while preserving
the original nonzero exit status.

Module planning, application, health checks, local-recipe resolution, bulk
package installation, base installation, and UKI generation have hard
deadlines. A stalled network request, package-manager lock, or subprocess thus
becomes a named failure. A rebuild rerun recreates the inactive candidate; a
checkpoint is diagnostic and never causes partially completed work to be
skipped.

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

The QEMU helpers support optional headless mode, localhost SSH forwarding,
QMP and retained serial logs; see [VM validation](docs/vm-validation.md). A successful shell test run is not
a substitute for completing bootstrap, boot, rebuild, and second boot in both
an Arch guest and a Fedora guest.

Fedora-specific backend assumptions and validation points are documented in
[docs/fedora.md](docs/fedora.md). Gaming-session details are in
[modules/gaming/README.md](modules/gaming/README.md).

## Desktop and private configuration

Plasma supports Arch and Fedora. Zephyrus Hyprland currently supports Arch,
with its public source packaged under `/usr/share/zephyrus-shell`. Desktop
selection persists across rebuilds; `rebuild.sh --desktop hyprland` switches the
candidate. See [profiles and Python tooling](docs/desktops.md).

Private configuration is optional and separate from installation. After login,
use the authenticated fetch/reviewed apply hook described in
[private hydration](docs/private-hydration.md).

## Current limits

- one disk, one login user, fixed UID/GID 1000, and the fixed layout above;
- no cross-distribution build or migration;
- no Secure Boot setup;
- no automatic boot rollback;
- home reconciliation is best effort rather than globally atomic;
- every rebuild downloads and installs a complete native base;
- Fedora boot behavior still requires end-to-end VM validation.
