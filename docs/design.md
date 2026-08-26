# Design contract

This document is the source of truth for the project. Code and other
documentation must follow it; existing behavior is not evidence that the
behavior is intentional.

## Purpose

The repository manages a personal Arch Linux or Fedora system with ordinary
Bash. It aims for a declarative *description* of the desired system without
claiming reproducibility, immutability, or complete package-state enforcement.

The installed roots are conventional mutable distributions. It is valid to
update the running system or install something manually. Those changes are
accepted drift. A later clean rebuild discards root-local drift unless a module
declares it again or explicitly preserves it.

## Native distribution boundary

Bootstrap runs from installation media of the distribution being installed:

```text
Arch ISO   -> Arch system
Fedora ISO -> Fedora system
```

The distribution is detected from `/etc/os-release`; it is never selected in a
configuration file. After installation, both A/B roots remain generations of
that same distribution. Cross-distribution builds and migrations are out of
scope.

Distribution lifecycle implementations live below `installer/distros/`. Native package
manager operations and manager-level configuration live in
`pm/arch/pacman.sh` and `pm/fedora/dnf.sh`. Repository and non-native
package-manager plugins live below `pm/` as described later. Keeping the native
manager inside its distro directory leaves room for another manager without
conflating it with the distro backend.

## Storage and boot model

The fixed layout is:

```text
EFI System Partition (FAT32)
└── EFI/Linux/
    ├── system-a.efi
    └── system-b.efi

LUKS2 partition
└── Btrfs filesystem
    ├── @root-a
    ├── @root-b
    └── @home
```

A and B are mutable Btrfs subvolumes, not separate disk partitions. Home is a
third, persistent subvolume. Firmware boots slot-specific unified kernel images
directly; the project does not install GRUB or systemd-boot as a boot manager.

Bootstrap destructively creates the layout and installs slot A. It creates B as
an empty subvolume but does not create a firmware entry that points to a missing
B UKI.

## Interactive bootstrap

`bootstrap.sh` asks for the target disk, hostname, login username, timezone,
locale, and console keymap. It then asks for the login and LUKS credentials at
the commands that create them. No installer `.env` file is required.

The non-secret answers are stored as root-owned system state in
`/etc/system/config`. Rebuild reads that file from the running root and
does not ask the same installation questions again. VM helper settings are
separate and may be placed in `.vm.env`.

## Mutable A/B lifecycle

Normal use does not require rebuilding or switching slots. The active root may
be updated and modified like any ordinary Arch or Fedora installation.

`rebuild.sh` always operates on the inactive slot:

1. Detect the running distro and active Btrfs root.
2. Delete and recreate only the inactive root.
3. Install a clean native base into it.
4. Run every module against the candidate.
5. Copy explicitly preserved machine state.
6. Generate the candidate's slot-specific UKI.
7. Reconcile candidate skeleton defaults into persistent home.
8. Put the candidate first in UEFI `BootOrder`.
9. Ask whether to reboot into it immediately.

Declining the reboot does not undo activation: the newly built slot is used on
the next ordinary reboot. The previous root and UKI remain mutable and manually
bootable from the firmware menu. Automatic boot-health rollback is not
currently provided.

A failure before activation leaves the running root and firmware order intact.
Home is mounted only after provisioning and UKI generation succeed.

Arch and Fedora bootstrap and retain their official stock kernels. Arch's UKI
preset and Pacman hook track the configured bootstrap package (normally
`linux`); Fedora selects the newest installed stock kernel and its
`kernel-install` hook refreshes only the running slot's UKI. Third-party gaming
kernels are not part of the platform contract: current stock kernels carry the
required AMD, Gamescope, and ASUS `asus-armoury` support without adding another
repository and kernel supply chain.

## Modules

Every `modules/**/*.sh` file runs, recursively, in lexical order. A module that
does not apply must guard itself and exit successfully—for example by checking
`DISTRO`, CPU/PCI vendor, DMI identity, or another hardware fact. Examples that
must not execute do not belong below `modules/`.

Modules run as trusted root code in isolated Bash processes inside the
candidate. They receive `HOME=/etc/skel`, the XDG skeleton paths, `SETUP_ROOT`,
`MODULE_DIR`, user identity, distro identity, and preservation/reconciliation
state. They must source `"$SETUP_ROOT/lib/module.sh"` before using the module
API and must not depend on functions or variables created by another module.

Lexical order is deterministic execution order, not a dependency mechanism.
Each module declares its own packages and prerequisites.

## Package declarations

The public interface is:

```bash
packages=(
    nano
    fedora:fedora-only-package
    arch:aur/arch-only-aur-package
    flathub/org.example.Application
)
pkg_install "${packages[@]}"
```

The grammar has exactly four forms:

```text
name                    native package on both supported distros
<distro>:<name>         native package only on that distro
<source>/<name>         shared source handled by pm/<source>.sh
<distro>:<source>/<name>
                        distro-specific source handled by
                        pm/<distro>/<source>.sh
```

The first slash separates the source from its opaque package/ref name, so names
may contain further slashes (for example Flatpak runtime refs).

There is no implicit source fallback:

- `flathub/app.id` resolves only to `pm/flathub.sh`;
- `fedora:terra/package` resolves only to `pm/fedora/terra.sh`;
- `arch:aur/package` resolves only to `pm/arch/aur.sh`;
- `aur/package` is an error because there is no shared `pm/aur.sh`;
- `arch/package` means an unscoped source named `arch`, not a native package.

Unknown distro scopes and missing plugins are errors, including typos in specs
that would otherwise be ignored on the current distro.

Use an unscoped native name whenever that exact name exists on Arch and Fedora.
Do not write both `arch:name` and `fedora:name` in that case. Distro scoping is
for different names, availability, or sources—not documentation noise.

There is one intentional Arch shorthand: an `arch:lib32-*` native-looking spec
is dispatched through `pm/arch/multilib.sh`. This enables Multilib only when a
selected declaration needs a 32-bit package. Packages without the `lib32-`
prefix, such as Steam, use the explicit `arch:multilib/<name>` form when they
must come from that repository.

## Package plugins

A plugin implements:

```bash
pm_enable                  # idempotently prepare its source
pm_install name...
pm_is_installed name
pm_remove name...          # used for temporary build dependencies
```

`pm_install` calls `pm_enable` before installation. Preparation is demand
driven: if no selected package spec refers to the plugin, the plugin is never
loaded, its package-manager dependency is not installed, and its repository is
not enabled. Enablement must also inspect persistent system state so repeated
module calls do not repeat setup.

A plugin may install native prerequisites with `pkg_install` and may enable a
second explicit source with `pkg_repo_enable`. It must not reinterpret another
plugin's syntax or silently fall back to another source.

Non-native managers install system-wide wherever the manager supports it:

- Flatpak uses the system installation;
- Cargo uses `/usr/local`;
- AUR output is installed through Pacman, while its unprivileged build state
  lives under `/var/lib/system`, not persistent `/home`.

User configuration may still be declared below `/etc/skel`; this is distinct
from installing package payloads into a user's persistent home.

## Local package recipes

Locally maintained native recipes are data, not package-manager plugins. They
live at:

```text
packages/<distro>/<name>/...
```

The implemented Arch route is `arch:pkgbuild/<name>`, handled by
`pm/arch/pkgbuild.sh`, which expects `packages/arch/<name>/PKGBUILD`. The AUR
plugin is independent: it installs `paru` explicitly from Chaotic-AUR. Fedora
may later use the same directory shape for spec files or another native recipe
format; no Fedora mechanism is invented until it is needed.

## Files and ownership

Modules can atomically write or append files with install-style metadata:

```bash
file_write [-m MODE] [-o OWNER] [-g GROUP] /path <<'EOF'
content
EOF

file_append [-m MODE] [-o OWNER] [-g GROUP] /path <<'EOF'
content
EOF
```

Replacing a file retains unspecified existing metadata. A new file defaults to
`0644 root:root`. Static module assets can be piped or redirected into
`file_write`, avoiding otherwise dangling files copied without explicit
ownership or permissions.

## Persistent home and selected machine state

Modules write user defaults into `/etc/skel`. After a successful candidate
build, the active and candidate skeletons are reconciled into the persistent
home. Candidate declaration changes win, unchanged user values remain, and
replaced files are backed up. `home_strategy` can override reconciliation for a
specific path.

The reconciliation engine runs outside the module phase, so its JSON, YAML, and
TOML tools (`jq` and `yq`) are part of each distro's base package set. Tools
needed by only specific declarations belong to those modules instead—for
example, the Gecko browser modules declare `crudini`, Kodi declares
`xmlstarlet`, and VS Code declares `jq`. There is no catch-all parser module.

`preserve_path` is for selected root-local machine state that must survive a
clean rebuild, such as machine identity, SSH host keys, network credentials, or
Bluetooth pairings. It is not a general backup mechanism.

## Non-goals

The project is not a reproducible build, immutable OS, package-state reconciler,
backup product, cross-distro installer, or unattended fleet provisioner. It
does not attempt to remove undeclared packages from the running mutable root;
clean rebuild is the reconciliation boundary.
