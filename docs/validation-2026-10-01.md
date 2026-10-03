# Desktop integration validation — 2026-10-01

This records the historical launcher-based fix. The current AutoConfig change
and its narrower validation are recorded in [the 2026-10-02 record](validation-2026-10-02.md).

## Environment and scope

Real QEMU/KVM guest, UEFI/OVMF, virtio graphics/network/storage, four virtual CPUs,
4 GiB RAM, separate 80 GiB disposable qcow2 and firmware variables. Installation
used `archlinux-2026.08.01-x86_64.iso` and the public repository over a read-only
9p share. The existing workstation VM disk was not modified. The test host was
`vm`, hostname `vm-hyprland`, login user `tester`; all credentials were disposable
test values. SSH/sudo access was explicitly added to the test guest for diagnosis.

This exercises the actual installer and desktop stack, not the full Zephyrus
workstation host's application collection. No private GitHub repository access
was required or performed, and no physical GA402RK behavior was tested.

## Arch Hyprland bootstrap and boot

`bootstrap.sh --healthchecks --non-interactive --disk /dev/vda --host-profile vm
--desktop hyprland --hostname vm-hyprland --username tester` completed through
package builds, configuration, home reconciliation, UKI generation and firmware
activation. Fifteen selected module healthchecks passed on the initial run.
The subsequent disk-only boot entered `@root-a`, accepted LUKS unlock and the
greetd password login, and visibly started Hyprland with the Zephyrus shell.

Observed installed versions:

| Component | Version |
| --- | --- |
| Firefox | 157.0-1.1 |
| Arkenfox template package | 144.0-1 |
| Zephyrus package | 20260930.g2724e41-1 |
| uv | 0.12.21-1.1 |
| Ruff | 0.16.9-1.1 |
| ty | 0.0.84-1.1 |

Zephyrus's installed revision was
`2724e41ca0a78e55ef11e1a10cd6f7bed468d9d0`. Its live process was
`quickshell -n -p /usr/share/zephyrus-shell`. The selected config persisted
`HOST_PROFILE=vm` and `DESKTOP=hyprland`; Plasma's session/configuration and Kodi
were absent. `hyprctl -i 0 configerrors` reported no errors. The user polkit agent,
main portal and Hyprland portal were active; hypridle was running. Super+L started
hyprlock and the test password unlocked it. Missing optional hardware backends
did not prevent the shell from loading. VM Mesa warnings were present in the
session log; they did not prevent the visible session.

## Arkenfox reproduction and fix

The actual package plan selected the local Arkenfox recipe from
`browsers/firefox`. Recipe resolution, checksum validation, build and package
installation all succeeded before Firefox's module apply. The target contained
the 79,987-byte `/usr/share/arkenfox/user.js` and the 80,396-byte generated
`~/.config/mozilla/firefox/default/user.js`. The recipes' producer path and the
module's consumer path already agreed.

A normal first launch of Firefox, with no profile argument, reproduced the
reported symptom: it created `rdtwlvew.default-release` and selected that new
profile. Its `profiles.ini` added `[Install4F96D1932A9F858E]` with
`Default=rdtwlvew.default-release`, leaving the managed `default` profile unused.
The original generated `Default=1` record was only the legacy default; it did not
bind this Firefox installation to the configured profile.

After applying the managed launcher and desktop-entry routing, a normal headless
launch wrote `default/prefs.js` and loaded the Arkenfox
`network.http.referer.XOriginTrimmingPolicy=2` preference plus local
`signon.rememberSignons=false` and `browser.startup.page=3` overrides.
`vm/verify.sh` passed after login, including this browser consumption test.
This establishes the reproduced failure's cause; it is not evidence of a missing
template or mismatched installation path.

## Maintenance issues found

The first bootstrap exposed orphaned build-helper daemons keeping the encrypted
candidate open during cleanup. Module package/configuration phases now use a
private PID namespace with a matching proc mount. Arch's base `pacstrap` operation
also gets a private PID/mount namespace so its keyring helpers cannot survive it.

The first rebuild attempt stopped before modifying the inactive slot because
`pacstrap` was absent from the installed Arch system. `arch-install-scripts` is
now in the native base package set. The disposable guest received that package
explicitly to retry the existing installation.

The return rebuild then reproduced `btrfs subvolume delete: Directory not empty`.
The inactive root contained systemd-created `var/lib/machines` and
`var/lib/portables` subvolumes. Deletion now uses Btrfs's recursive operation with
a transaction commit, explicitly checks the target is a configured inactive
root, rejects symlinks, and mounts subvolume ID 5 for the operation. The retry
deleted only those descendants and `@root-a`; `@root-b` and `@home` remained.
Older native btrfs-progs without this operation fail clearly before deletion.

Shared-home reconciliation also removed unchanged Hyprland configs during the
first switch to Plasma. The Hyprland module now registers those four files with
`never` deletion policy so a subsequent desktop switch keeps a usable fallback.
The real reconciler's focused test confirms that this policy preserves the
session shim while ordinary obsolete defaults are still removed.

## Arch Plasma rebuild and boot

From the booted Hyprland root, `rebuild.sh --desktop plasma --healthchecks`
successfully built clean `@root-b`, applied all 19 selected leaves/healthchecks,
reconciled home, generated the UKI and selected the new firmware entry. Kodi,
its add-ons, mpv and the existing Plasma applet recipes installed successfully.

Disk-only boot entered `@root-b` and started a visible Plasma session using the
existing login manager/autologin policy. Its installed config persisted
`DESKTOP=plasma`, while `@root-a` retained its previous choice. Zephyrus and greetd
were absent from the Plasma root. `vm/verify.sh` passed: a live plasmashell, system
Kodi installation, native Python/pip/uv/Ruff/ty, and loaded Arkenfox preferences.
`arch-install-scripts 31-2` was present and Plasma Login Manager was active.
The VM-only SSH firewall exception was limited to the NAT gateway; it is not a
public workstation rule.

## Return to Hyprland

The final `rebuild.sh --desktop hyprland --healthchecks` from Plasma completed
with all 16 selected module healthchecks passing. It recreated `@root-a` after
the safe recursive deletion, installed the final Firefox launcher and Hyprland
home policies, reconciled the shared home and selected the A UKI again. After
completion, no gpg-agent/dirmngr build helper survived, and no `/mnt/system`
candidate mount remained. This run exercises both the base and module PID
namespace changes.

The rebuilt A root booted, accepted the greetd login and visibly started Zephyrus
from the packaged directory. The final `vm/verify.sh` passed again, along with
the user portal/polkit service and Hyprland config-error checks. Kodi and Plasma
were absent; Python tools and the consumed Firefox preferences were correct.

A one-time firmware BootNext into the retained B entry then booted Plasma again.
Its complete post-login verification passed after the Hyprland rebuild, including
Kodi, Python and Firefox. The shared Hyprland shim remained available for the A
root, while the default BootOrder still selected A first. The test VM was then
shut down; its disk, variables, screenshots and logs are retained locally.

## Automated and remaining validation

`bash tests/run.sh` passes, including both Arch desktop graphs, Fedora Plasma
preflight, the Fedora Hyprland rejection, CLI/menu/configuration behavior,
Firefox prerequisites/launcher/desktop actions, and private-hook isolation,
permissions and explicit apply, fallback-home retention, and inactive-slot
deletion guards. Bash syntax checks, ShellCheck at error severity
for changed scripts, and `git diff --check` passed.

Fedora Hyprland remains explicitly unsupported: its published Qt 5 terminal
runtime does not meet the current Zephyrus Qt 6/Lua session requirements. Fedora
Plasma has graph/preflight coverage here, not a live Fedora installation result.
Hardware-dependent portals, polkit actions and physical laptop behavior still
need user acceptance on the installed GA402RK. Thermal shutdown, battery video,
hybrid GPU, refresh-rate/VRR/HDR, fan and suspend behavior were not validated.

Local ignored evidence is retained under `vm/logs/`: a Hyprland boot screenshot,
post-login verification, first-launch Firefox profile metadata and an archive of
the actual package plan, resolved recipes and package/module execution logs,
plus Plasma/fallback and final Hyprland boot/build verification.
