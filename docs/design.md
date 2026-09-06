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
`sources/arch/pacman.sh` and `sources/fedora/dnf.sh`. Repository and non-native
package-manager plugins live below `sources/` as described later. Keeping the native
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
Both distro backends deliberately add `mitigations=off` to the UKI command line
for this personal workstation. This disables classes of CPU vulnerability
mitigations and weakens isolation from untrusted local code.

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

The account password remains available for the lock screen, TTY, SSH, and
other explicit authentication. The configured workstation policy grants that
user passwordless sudo and passwordless interactive Plasma Login Manager
access; LUKS unlock and the lock screen are the intended physical boundaries.

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

Arch and Fedora bootstrap with their official stock kernels. On a CPU that
passes the x86-64-v3 runtime gate, the selected `base/package-sources` leaf
enables ALHP and upgrades available packages before bulk module installation;
Fedora
retains its official stock kernel. Arch's UKI preset and Pacman hook track the
configured bootstrap package (normally `linux`), including its ALHP rebuild when
available; Fedora selects the newest installed stock kernel and its
`kernel-install` hook refreshes only the running slot's UKI. Patched third-party
gaming kernels remain outside the platform contract: upstream-derived kernels
carry the required AMD, Gamescope, and ASUS `asus-armoury` support.

## Modules

`hosts/<hostname>.sh` is the sole selection root and contains an ordered
`modules` array. Aggregate modules contain an explicit ordered `members` array.
Selecting `gaming` expands that list; selecting `gaming/steam` selects only the
leaf. Filesystem discovery is not execution, and duplicate selections execute
once.

Modules run as trusted root code in isolated Bash processes inside a private
mount namespace rooted at the candidate. Unlike a plain chroot, this allows
nested user namespaces required by sandboxed installers such as Flatpak, and
module-created mounts disappear when the process exits. Modules receive
`HOME=/etc/skel`, the XDG skeleton paths, `SETUP_ROOT`, `MODULE_DIR`, user
identity, distro identity, and preservation/reconciliation state. They must
source `"$SETUP_ROOT/lib/module.sh"`, keep mutations inside `module_apply`, and
finish with `module_entrypoint "$@"`. A `module_check` function may skip a
hardware- or distro-specific leaf during planning. The check is repeated before
application so changed hardware state is fatal.

Planning evaluates every selected module before module mutation. Sources are
then prepared, packages are deduplicated and installed in source groups, and
leaf `module_apply` functions run in resolved order. `requires` names absolute
module selectors and is reserved for real technical dependencies; cycles are
fatal.

The planner rejects symlinks in a leaf's `files/` overlay and rejects two
selected leaves that own the same overlay path. This makes automatic copying
root-relative without giving a symlink an opportunity to escape its apparent
destination. Paths generated by `module_apply` remain the module author's
responsibility.

## Package declarations

The public interface is:

```bash
packages=(
    nano
    fedora:fedora-only-package
    arch:aur/arch-only-aur-package
    flathub/org.example.Application
)
module_entrypoint "$@"
```

The grammar has exactly four forms:

```text
name                    native package on both supported distros
<distro>:<name>         native package only on that distro
<source>/<name>         shared source handled by sources/<source>.sh
<distro>:<source>/<name>
                        distro-specific source handled by
                        sources/<distro>/<source>.sh
```

The first slash separates the source from its opaque package/ref name, so names
may contain further slashes (for example Flatpak runtime refs).

The distro prefix controls applicability, not necessarily provider location.
Lookup is deterministic: leaf-scoped, leaf-shared, global-scoped, then
global-shared. This permits a package to be Fedora-only while using a genuinely
shared manager such as Cargo:

- `flathub/app.id` resolves only to `sources/flathub.sh`;
- `fedora:terra/package` resolves only to `sources/fedora/terra.sh`;
- `fedora:cargo/package` resolves to `sources/cargo.sh` when no closer scoped
  provider exists;
- `arch:aur/package` resolves only to `sources/arch/aur.sh`;
- `aur/package` is an error because there is no shared `sources/aur.sh`;
- `arch/package` means an unscoped source named `arch`, not a native package.

Unknown distro scopes and missing plugins are errors, including typos in specs
that would otherwise be ignored on the current distro.

Use an unscoped native name whenever that exact name exists on Arch and Fedora.
Do not write both `arch:name` and `fedora:name` in that case. Distro scoping is
for different names, availability, or sources—not documentation noise.

There is one intentional Arch shorthand: an `arch:lib32-*` native-looking spec
is dispatched through `sources/arch/multilib.sh`. This enables Multilib only when a
selected declaration needs a 32-bit package. Packages without the `lib32-`
prefix, such as Steam, use the explicit `arch:multilib/<name>` form when they
must come from that repository.

## Package plugins

A plugin implements:

```bash
source_prepare                  # idempotently prepare its source
source_install name...
source_is_installed name
source_remove name...          # used for temporary build dependencies
```

The package-plan executor calls `source_prepare` before installation.
Preparation is demand driven: if no selected package or explicit `sources`
declaration refers to the plugin, it is never loaded and its repository is not
enabled. Preparation must inspect persistent state so reruns do not repeat
setup.

A plugin may install native prerequisites with `pkg_install` and may enable a
second explicit source with `pkg_repo_enable`. It must not reinterpret another
plugin's syntax or silently fall back to another source.

Non-native managers install system-wide wherever the manager supports it:

- Flatpak uses the system installation;
- Cargo uses `/usr/local`;
- npm packages use the distribution npm installation's global prefix;
- AUR output is installed through Pacman, while its unprivileged build state
  lives under `/var/lib/system`, not persistent `/home`.

User configuration may still be declared below `/etc/skel`; this is distinct
from installing package payloads into a user's persistent home.

## Local package recipes

Locally maintained native recipes are data owned by their consuming leaf:

```text
modules/<leaf>/packages/<distro>/<name>/...
```

Local recipes are a fallback, not a preferred source. Modules use an existing
enabled repository or the AUR whenever it already carries the package, and use
`arch:`/`fedora:` scopes when availability differs.

The Arch route is `arch:pkgbuild/<name>`, handled by `sources/arch/pkgbuild.sh`,
which expects `packages/arch/<name>/PKGBUILD` below the declaring leaf. The AUR
plugin is independent:
it installs `paru` explicitly from Chaotic-AUR.

The Fedora route is `fedora:rpmspec/<name>`, handled by
`sources/fedora/rpmspec.sh`. It expects both
`packages/fedora/<name>/<name>.spec` and `sources.sha256` below that leaf. The
plugin resolves
`BuildRequires`, downloads spec sources with `spectool`, verifies every source,
builds as an unprivileged account, and installs the resulting RPM through DNF.
Recipe names must match their installed native package names so installed-state
checks remain ordinary RPM queries.

`run_modules` copies only selected leaves' `packages/` trees into the
candidate's temporary `/run`. The generic `packages/update.sh` invokes each
recipe-local `update.sh` for the selected distribution and exports that leaf's
ephemeral recipe root to the builder source. Release-based recipes resolve the
latest non-draft, non-prerelease GitHub release; commit-based recipes resolve
the default branch head and read their version from upstream metadata. Sources
are downloaded and hashed before the package builder is called. Resolution is
fail-closed: an unavailable API, source, or checksum aborts the rebuild rather
than silently using a stale snapshot.

## Files and ownership

A leaf may contain `files/`; its contents are copied as a root-relative overlay
immediately before `module_apply`. For example,
`modules/example/files/etc/example.conf` becomes `/etc/example.conf`.
Generated or merged content uses the helpers below.

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
`0644 root:root`. Static module assets belong in the leaf's `files/` overlay.
Generated or merged content uses `file_write` or `file_append` so replacement
is atomic and metadata is explicit.

## Execution bounds and failure state

The installer logs a checkpoint before every destructive or long-running major
phase and before every individual module. The current state is available at
`/run/system-provision-state` and is copied into the mounted candidate at
`/var/lib/system/provision-state`. Cleanup reports this state on failure without
masking the failing exit status.

Network-heavy and package-heavy boundaries have finite deadlines. A timeout is
a failure, never permission to continue with a partial result. The checkpoint
is diagnostic rather than an instruction to skip work: rebuild recovery starts
again with a clean inactive root, while package and module operations remain
safe to repeat within a fresh candidate.

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

`/etc/machine-id` is preserved by the rebuild lifecycle because a clean root is
still the same machine. `preserve_path` is for module-owned root-local state
that must survive a clean rebuild, such as network credentials or Bluetooth
pairings. The SSH-server module likewise owns preservation of its host keys.
This is not a general backup mechanism.

## Non-goals

The project is not a reproducible build, immutable OS, package-state reconciler,
backup product, cross-distro installer, or unattended fleet provisioner. It
does not attempt to remove undeclared packages from the running mutable root;
clean rebuild is the reconciliation boundary.
