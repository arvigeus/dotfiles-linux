# Gaming stack

This module provides a conventional Linux desktop gaming stack and an optional
controller-first Steam session. It is intentionally narrower than a gaming
distribution: the target is the GA402RK workstation, not every handheld and
HTPC supported by Bazzite, Nobara, ChimeraOS, or CachyOS.

The governing rule is one owner per concern. Gamescope owns the dedicated
session, Steam Input owns game-controller mapping, `asusd` owns ASUS platform
profiles and CPU EPP, the kernel/Mesa own AMD graphics, and PipeWire/WirePlumber
own audio. Nothing forces maximum performance during ordinary desktop use.

## Supported hardware assumptions

- ASUS ROG Zephyrus G14 GA402RK-L8149 (2022)
- Ryzen 9 6900HS with Radeon 680M and Radeon RX 6800S (`1002:73ef`)
- internal 2560x1600, 120 Hz adaptive-sync panel
- external Dell 4K display around 75 Hz; exact connector and HDR/VRR capability
  must be discovered from its EDID on the installed machine
- original Steam Controller, ordinary gamepads, and a Steam Deck used as a
  separate Steam/Remote Play device

The DMI guard in `modules/hardware/devices/zephyrus/module.sh` keeps ASUS policy off
other machines. The GA402-specific GPU preference is conditional at runtime:
when firmware has disabled the RX 6800S, Gamescope chooses an available GPU
instead of failing.

### Known unresolved hardware problems

Two observed problems are design inputs, not solved claims:

- the laptop has sometimes reached a thermal shutdown while gaming, even after
  a `zephyrusctl` "gaming" profile was selected;
- battery video playback has regressed to roughly one hour, while two hours was
  previously achievable on this same machine.

Provisioning therefore installs `/usr/local/bin/system-g14-observe`, a read-only
recorder for the physical-machine investigation below. It does not apply an
automatic gaming preset yet. Selecting a profile name without measuring the
combined CPU/APU/dGPU power envelope, junction temperatures, and fan response
has already proved insufficient. Exact PPT and fan values must come from a
controlled GA402 observation rather than a copied Steam Deck or RyzenAdj value.

## Architecture

| Concern | Owner | Repository implementation |
| --- | --- | --- |
| Games and compatibility | native Steam, Steam Linux Runtime, Proton | `steam.sh`, one Proton manager (`ProtonPlus`), Protontricks |
| Dedicated shell | Gamescope launching Steam Gamepad UI | `gamescope-session/module.sh`, its `files/` overlay |
| Overlay | Gamescope Mangoapp in gaming mode; MangoHud on explicit desktop use | `mangohud.sh` |
| Graphics | distro Mesa/RADV and 32-bit Vulkan userspace | `hardware/gpu/amdgpu.sh` |
| Platform power/thermals | `asusd`, kernel `asus-armoury`, ASUS firmware | `hardware/devices/zephyrus/module.sh` |
| Hardware diagnosis | read-only sysfs, ASUS, DRM, battery, and process sampling | `system-g14-observe` |
| Per-application GPU choice | `switcheroo-control` plus ASUS firmware GPU mode | `hardware/devices/zephyrus/module.sh` |
| Controllers | kernel HID drivers, Valve udev rules, Steam Input | `steam.sh` |
| Audio | PipeWire and WirePlumber | existing audio module; no gaming override |
| Memory pressure | `zram-generator` defaults | `hardware/memory/zram.sh` |
| Login/session selection | Plasma Login Manager | ordinary Wayland session desktop file |

The gaming-session process tree is deliberately simple:

```text
Plasma Login Manager
  `- /usr/local/bin/system-gaming-session
       `- gamescope --steam ...
            `- steam -gamepadui
```

Steam exiting makes Gamescope exit; Gamescope exiting returns control to the
login manager. There is no privileged SteamOS updater, display-manager restart
helper, systemd user wrapper, or second session daemon to recover.

### Distribution boundary

Policy and installed files are shared. Only package provenance differs:

| Capability | Arch | Fedora |
| --- | --- | --- |
| Steam | `multilib/steam` | RPM Fusion `steam` |
| Controller permissions | `multilib/steam-devices` | Fedora `steam-devices` |
| Gamescope/MangoHud/zram | official packages plus `lib32-mangohud` | official packages plus `mangohud.i686` |
| Mesa/RADV 32-bit | ALHP v3 overlay with official multilib fallback | `.i686` Mesa/Vulkan packages |
| General package provenance | CPU-gated ALHP v3 overlay, then official Arch fallback | official Fedora repositories |
| ASUS CLI/GUI | OGC `asusctl`, `rog-control-center` | Terra `asusctl`, `asusctl-rog-gui` |
| Hybrid GPU service | official `switcheroo-control` | official `switcheroo-control` |

The OGC Arch and Terra Fedora repositories are used only where the repository's
existing package abstraction declares them. No distro's kernel, Mesa, session
framework, or handheld package set is transplanted into the other.

## Desktop experience

Steam is installed natively on both distributions so it shares the host's Mesa
stack and Valve device rules. Native Steam still launches games through the
Steam Linux Runtime where the title requests it. Proton's per-game selection
remains a Steam setting. ProtonPlus is the single GUI for optional GE/custom
compatibility tools; Protontricks remains available for prefix repair. Custom
Proton is not made a global default.

On Arch this specifically means the ordinary `steam` package, not globally
forcing `steam-native-runtime`; bypassing Valve's runtime is a per-title
diagnostic, not system policy. Steam shader pre-caching and pipeline-cache
behavior also remain at Steam/Mesa defaults rather than being disabled or
redirected globally.

Heroic, Lutris, and Bottles stay sandboxed as independent launchers. Their
Flatpak runtimes resolve their own Vulkan-layer extensions. The repository no
longer pins obsolete `23.08` Gamescope/MangoHud runtime extensions or downloads
an unpinned MangoHud configuration during provisioning.

No global `MANGOHUD`, `ENABLE_VKBASALT`, Vulkan ICD, RADV, shader-cache, or
Proton environment variables are set. RADV is selected by the installed AMD
Vulkan packages without an override. Both 64-bit and 32-bit Mesa/Vulkan paths
are installed for older games.

## Gaming session

Select **Steam Gaming Mode** at the login screen. The session launcher uses:

```text
gamescope --backend drm --steam --xwayland-count 2 --adaptive-sync --mangoapp \
  [--prefer-output CONNECTORS] [--prefer-vk-device 1002:73ef] \
  [--hdr-enabled] -- steam -gamepadui
```

- The DRM backend makes Gamescope the compositor for the login session rather
  than nesting it inside the desktop.
- `--steam` enables Gamescope's current Steam integration and exports the
  capabilities Steam expects. We do not duplicate those environment variables.
- Two Xwayland servers match the separation used by mature Gamescope sessions
  without importing their handheld and distribution quirks.
- Adaptive sync is requested only when the active connector supports it.
- Mangoapp gives Steam's Gamescope UI access to the performance overlay; the
  overlay is not forced over desktop applications.
- Connected external outputs are ordered before internal panels. If there is
  no readable DRM connector information, Gamescope chooses by itself.
- The RX 6800S is preferred only while its PCI device exists. Integrated-only
  firmware mode therefore remains usable.
- Steam runs in ordinary Gamepad UI, not with `-steamdeck`. This avoids telling
  Steam that the laptop is a handheld and avoids depending on SteamOS firmware,
  updater, TDP, or session-switch helpers that do not exist here.

The launcher intentionally does not force an output mode, refresh rate,
rendering resolution, scaling filter, frame limit, or tearing policy. Steam's
per-game controls and the display's preferred mode remain authoritative.

### Configuration

System policy is read from `/etc/system/gaming-session.conf`; the GA402 module
writes only its PCI GPU preference. A user can override it in
`~/.config/system/gaming-session.conf`:

```ini
# auto, or an ordered DRM connector list from drm_info/sysfs
SYSTEM_GAMING_OUTPUT=DP-1,HDMI-A-1,eDP-1

# auto, or a PCI vendor:device ID
SYSTEM_GAMING_GPU=1002:73ef

# Experimental until the actual display path is validated
SYSTEM_GAMING_HDR=0
```

Only these three literal key/value settings are accepted; the file is not
executed as shell code. Environment values with the same names take final
precedence for one launch.

To inspect the resolved command without starting a session:

```bash
SYSTEM_GAMING_DRY_RUN=1 /usr/local/bin/system-gaming-session
```

### Login and exit policy

The repository installs the selectable session but does not enable autologin.
That preserves workstation security and prevents an accidental gaming loop. If
console-style boot is desired, configure Plasma Login Manager explicitly after
the session has passed the manual tests. Its equivalent configuration is:

```ini
[Autologin]
Relogin=false
Session=system-gaming.desktop
User=YOUR_USER
```

Keep `Relogin=false`: after **Exit Steam**, a crash, or Gamescope failure, the
machine should return to the greeter instead of immediately relaunching the
failed session. Select Plasma there to return to the desktop.

Suspend is handled by Steam/logind and the normal kernel drivers. No handheld
power-button interception daemon is installed. This is less magical than
SteamOS but does not steal laptop lid or power-button policy from the desktop.

## Performance and hardware management

### Kernel and graphics

Fedora uses its stock, current kernel. Arch enables ALHP's `x86-64-v3`
repositories only when glibc confirms CPU support, so the final Arch kernel and
other available packages may be ALHP rebuilds of Arch package sources. The
Ryzen 9 6900HS is expected to pass that gate; an unsupported VM or machine keeps
the official Arch repositories. ALHP remains a third-party binary repository,
may lag Arch during large rebuilds, and is not treated as measured evidence of
a gaming, thermal, or battery improvement.

The former OGC kernel path was removed: its only concrete need was access to
gaming and ASUS work that is now upstream, while replacing the bootstrap
kernel complicated UKI selection and Fedora supply-chain verification. ALHP
does not add that OGC patch set, but its increased package release can still
break directly linked out-of-tree kernel-module packages; use DKMS variants if
such a module is later introduced. Current upstream-derived kernels remain the
expected delivery path for `asus-armoury` (merged for Linux 6.19).

Mesa/RADV, firmware, and Vulkan loaders come from the selected distribution or,
on Arch, the matching ALHP v3 overlay with official repository fallback. No
patched Mesa or latency layer is mixed into the stack. LACT was removed:
continuous GPU clock/voltage management is not the chosen control plane for a
firmware-managed laptop dGPU.

### ASUS power, fans, and GPU modes

`asusd` is the sole owner of platform profiles and CPU energy-performance
preference. `power-profiles-daemon`, `tuned`, and `tuned-ppd` are masked on this
ASUS machine because current ASUS upstream documentation warns that concurrent
ownership races on `/sys/firmware/acpi/platform_profile` and CPU EPP. TLP and
auto-cpufreq are not installed.

On a current kernel/firmware combination, these are the realistic controls:

| Control | GA402 strategy | Confidence |
| --- | --- | --- |
| Platform profile | `asusd` Quiet/Balanced/Performance policy | expected and historically supported |
| AC vs battery | `asusd` persists separate policy and EPP behavior | expected; verify the generated `/etc/asusd/asusd.ron` |
| Fan curves | ASUS WMI through `asusctl`/ROG Control Center | expected; supported curve ranges must be queried |
| CPU/APU/dGPU PPT/TDP | `asus-armoury` firmware attributes exposed by `asusctl armoury` | conditional on firmware; not Deck-compatible TDP |
| CPU boost | no custom switch is installed | indirect influence through profile/EPP only unless the kernel exposes a supported control |
| GPU application choice | `switcheroo-control` in hybrid mode | supported desktop mechanism |
| Firmware GPU/MUX mode | ASUS tooling, applied safely by `asus-shutdown` when required | conditional; inspect this unit's reported capabilities |
| Battery charge limit | ASUS tooling when firmware advertises it | expected; verify on hardware |

A historical [`asusctl` GA402RK support
report](https://gitlab.com/asus-linux/asusctl/-/issues/301) from the exact board
reported platform profiles, CPU/GPU fan curves, charge-threshold control, panel
overdrive, and dGPU disable. It explicitly reported **no GPU MUX** at that
firmware/kernel revision. That is useful model evidence, not a promise about
the currently installed firmware: `asusctl info --show-supported` remains
authoritative. In particular, do not label hybrid/dGPU-disable as a hardware
MUX switch, and do not assume current `asus-armoury` PPT attributes exist until
`asusctl armoury list` shows them.

Run these before relying on a control:

```bash
asusctl info --show-supported
asusctl profile list
asusctl profile get
asusctl armoury list
asusctl fan-curve --help
systemctl status asusd.service asus-shutdown.service
```

The exact CLI surface changes with `asusctl`; use `asusctl --help` and the
reported subcommand help if a command above moved. ROG Control Center is
installed but not autostarted, and provisioning writes no fan curve or PPT.
Firmware limits are safety policy, so a future preset must be based on readings
and thermals from this exact machine. Some ASUS PPT controls become available
only with an active custom fan curve; that is not silently enabled here.

RyzenAdj was removed because its `/dev/mem` control path is a brittle duplicate
of the upstream firmware interface. Cardwire was removed because its eBPF-LSM
GPU blocking and smart external-display switching are still described upstream
as early development. `switcheroo-control`, kernel runtime PM, and ASUS firmware
mode selection are the maintained baseline.

This baseline is intentionally measurable rather than self-declared optimal.
`asusd` normally permits separate AC and battery profile policy, but its actual
configuration and the firmware interfaces must be captured on this machine.
There is no launch-time hook that blindly selects Performance: higher platform
power can worsen the shutdown problem, while a label alone does not bound the
RX 6800S or the shared cooling system.

### GameMode, scheduling, and memory

GameMode is not installed. Its platform-profile/governor actions overlap the
chosen `asusd` authority, and Bazzite itself currently removes GameMode from its
desktop image. If a game has a measured scheduling or I/O-priority problem, it
can be reconsidered with all power/profile actions disabled in GameMode's
configuration.

The stock scheduler is used. `ananicy-cpp`, `scx_lavd`, IRQ scripts, and gaming
sysctls were not adopted without GA402 benchmarks. CachyOS's tuned kernel/repo
is an integrated product choice, not a list of portable settings.

The installer does set `mitigations=off` in both distro UKIs as an explicit
owner-selected workstation security tradeoff. It is not a measured gaming
optimization, and it weakens isolation from untrusted local code.

`zram-generator` supplies one compressed swap device using upstream defaults:
half of RAM capped at 4 GiB. This improves behavior during shader compilation
or memory spikes without adding an OOM daemon or VM sysctl folklore. Zram does
not support hibernation; suspend-to-RAM is the intended gaming-session path.

## Displays, VRR, and HDR

The desktop remains entirely under Plasma/KScreen. The dedicated Gamescope
session uses one preferred output and leaves mode selection dynamic:

1. connected external connectors, in sysfs order;
2. connected internal eDP/DSI/LVDS panels;
3. Gamescope auto-selection if neither can be discovered.

This favors the external 4K display when docked without hard-coding its
connector name. It also avoids forcing 2560x1600 assumptions onto the Dell or
4K assumptions onto the internal panel. Override `SYSTEM_GAMING_OUTPUT` only if
connector enumeration chooses the wrong port.

VRR is requested through `--adaptive-sync`; it only works if the active output,
EDID, cable, GPU connector, and kernel driver all expose adaptive sync. A 75 Hz
mode is not evidence by itself. Gamescope/Steam can provide per-game frame
limits; no repository-wide cap is imposed.

HDR is off by default. `SYSTEM_GAMING_HDR=1` adds `--hdr-enabled`, but success
also requires an HDR-capable display path, Gamescope WSI support for the game,
correct EDID metadata, and a game that emits HDR. Gamescope can tonemap an HDR
client into SDR when HDR output is disabled. Validate SDR colors as well as HDR
before keeping the option enabled. The internal panel is not assumed to offer a
usable Linux HDR path merely because its Windows marketing may mention HDR or
Dolby features.

Multi-monitor desktop arrangements do not carry into gaming mode; embedded
Gamescope is treated as a single-output console compositor. This reduces
hotplug and scaling ambiguity. Test both the internal-only and docked paths.

## Controllers

The distro `steam-devices` package installs Valve's maintained udev permissions,
including the original Steam Controller. The kernel's HID drivers and Steam
Input then provide pairing, mapping, desktop navigation, and per-game layouts.
No custom udev rule or global SDL mapping is maintained here.

The Steam Controller should be paired and updated from Steam; test both its
normal game input and Gamepad UI navigation. Ordinary gamepads follow the same
Steam Input path.

BlueZ remains the system pairing authority. Because Steam is not forced into a
fake Deck mode, this repository does not promise a SteamOS-style Bluetooth
settings panel inside Gamepad UI. Pair Bluetooth controllers once from Plasma;
they should reconnect in the dedicated session. The Steam Controller's Valve
receiver continues to use Steam's own pairing flow.

A Steam Deck is not treated as internal hardware of this laptop. It can act as
a separate client through Steam Remote Play/Steam Link, and supported ordinary
controller transports can be used normally, but HHD/InputPlumber are not needed
to manage the Deck from the G14. HHD supports Windows handheld hardware, not
this GA402 laptop; InputPlumber's virtual-controller composition solves built-in
handheld controls that the G14 does not have.

## Audio and networking

The existing PipeWire/WirePlumber setup owns speakers, HDMI/DisplayPort audio,
Bluetooth audio, and controller audio. No fixed quantum or low-latency override
is applied: those settings increase power/CPU cost and can make Bluetooth less
reliable without fixing a demonstrated game problem. Check the active sink
after display hotplug with `wpctl status`.

No network sysctls, qdisc replacement, TCP timeout, DNS, or NIC interrupt tweak
is labeled a gaming optimization. Latency problems should be measured by link
type, route, and game before changing global policy.

## Existing-module audit

What was sound:

- separate Steam, Gamescope, MangoHud, Mesa/Vulkan, audio, and Bluetooth modules;
- native Steam plus 32-bit AMD userspace;
- DMI-scoped ASUS support and an RX 6800S PCI identity;
- keeping overlays opt-in rather than setting a global environment variable;
- desktop launchers remaining separate from the core console session.

What was conflicting or unnecessarily broad:

- `asusd` and power-profiles-daemon both managed platform profile/EPP;
- Cardwire replaced switcheroo-control while still early-stage;
- LACT, RyzenAdj, GameMode, PowerStation, and SteamOS Manager added overlapping
  power-control paths;
- InputPlumber, HHD-style concepts, OpenGamepadUI, and PowerStation targeted
  handheld controls absent on this laptop;
- three Proton managers duplicated one job;
- vkBasalt and an experimental low-latency Vulkan layer were installed without
  a machine-specific problem;
- third-party Gamescope session packages brought SteamOS updater, SDDM, and
  immutable-image assumptions into a mutable Plasmalogin system;
- OGC kernels replaced both distro kernels without a remaining required patch;
- hard-coded internal-panel refresh values did not describe the docked 4K path.

What was missing:

- official Valve controller permissions as an explicit dependency;
- a repository-owned, inspectable session lifecycle;
- dynamic output/GPU fallback and conservative HDR policy;
- coherent ownership of ASUS power/profile state;
- durable upstream revisions, rejection rationale, and hardware test guidance;
- a read-only way to correlate CPU and dGPU temperatures, fan speed, battery
  discharge, GPU runtime PM, profiles, and kernel evidence over time;
- bounded compressed swap for game/shader memory spikes.

### Audit of the previous `zephyrusctl` experiment

The user's [`arvigeus/zephyrusctl`](https://github.com/arvigeus/zephyrusctl)
was reviewed at commit `3d1b09cafa30f46170c814a8e1ab6eea9c0d0a91` (2026-07-09).
Its goal—different quiet battery and bounded gaming policies—is valid, but the
implementation could not reliably enforce that result:

- it identifies the RX 6800S as `1002:73ff`; this GA402RK's RX 6800S is
  `1002:73ef`, so the selection environment may target no matching device;
- its gaming RyzenAdj preset sets an 85 C CPU temperature target but no STAPM,
  fast-PPT, or slow-PPT ceiling. It therefore does not define a CPU power
  envelope and cannot directly bound the dGPU die, GPU junction, VRM, or shared
  heat-pipe load;
- it hard-codes PCI slot `0000:03:00.0`, connector `eDP-2`, and refresh rates,
  which are not stable hardware identities across firmware, boot modes, and the
  external display path;
- a 30-second timer reapplies RyzenAdj because the values drift when firmware
  policy changes. That is evidence of competing control planes, not reliable
  ownership;
- `powertop --auto-tune` changes many unrelated device knobs and offers no
  declarative rollback short of restoring each value or rebooting.

The experiment is replaced by upstream ASUS ownership plus observation. It
should remain disabled during controlled tests so its timer cannot rewrite the
state being measured. The useful intent may later become a small `asusd`/
`asus-armoury` preset after the laptop exposes its supported attributes and
measurements establish safe bounds.

### Existing component disposition

| Previous component | Action | Reason |
| --- | --- | --- |
| `meta.sh` fonts/input | KEEP, trim | Steam's text/input baseline remains; updater/AUR build packages did not belong here |
| Steam | MODIFY | retain native client and add official Valve device rules |
| Gamescope | KEEP | official distro package is current and sufficient |
| Gamescope session packages | REPLACE | local wrapper removes distro, updater, SDDM, and handheld coupling |
| MangoHud | MODIFY | keep 32-bit support and add a small on-demand config |
| GameMode | REMOVE | overlapping, unmeasured platform/governor control |
| vkBasalt and Vulkan low-latency layer | REMOVE | effects/experimental layers without a target problem |
| GOverlay | REMOVE | unnecessary GUI after the simple MangoHud config and vkBasalt removal |
| InputPlumber | REMOVE | no built-in handheld controller to compose |
| PowerStation | REMOVE | generic handheld TDP daemon duplicates ASUS firmware control |
| OpenGamepadUI | REMOVE/WATCH | Steam Gamepad UI is primary; optional shell is not mature enough |
| SteamOS Manager and helper overrides | REMOVE | device gates omit GA402 and lifecycle assumes SteamOS/SDDM/image updates |
| ProtonUp-Qt | REMOVE | duplicated ProtonPlus |
| ProtonPlus and Protontricks | KEEP | one custom-tool manager and one prefix repair tool |
| Bottles, Heroic, Lutris | KEEP, trim Lutris | useful independent launchers; let Flatpak resolve current extensions |
| UMU launcher module | REMOVE | Heroic/Lutris already own non-Steam runners; Fedora source added a Bazzite COPR solely for it |
| Game-specific modules | KEEP, unaudited | applications are separate from platform/session architecture |
| OGC kernel modules | REMOVE | stock current kernels supply the required upstream interfaces |
| LACT and RyzenAdj | REMOVE | duplicate privileged laptop power writers |
| Cardwire | REMOVE/WATCH | switcheroo-control is the stable baseline while Cardwire matures |

The game-specific modules under `games/` were outside this platform-stack audit
and remain unchanged.

## Feature classification

| Feature | Class | Decision |
| --- | --- | --- |
| Native Steam + Steam Linux Runtime/Proton | ADOPT | Normal distro integration and best access to the host AMD stack |
| ProtonPlus + Protontricks | ADAPT | One manager plus one repair tool; no global custom Proton |
| Dedicated Gamescope login session | ADAPT | Repository-owned wrapper, no image/handheld framework |
| Gamescope Steam integration, two Xwaylands, adaptive sync, Mangoapp | ADOPT | Current upstream interfaces solve console-session needs |
| Dynamic output and conditional RX 6800S preference | ADAPT | Covers internal/external and integrated-only modes |
| HDR output | WATCH | Implemented as opt-in; requires actual display-path validation |
| MangoHud | ADOPT | Available on demand, never globally injected |
| Distro Mesa/RADV and 32-bit userspace | ALREADY COVERED | Existing AMD module was basically correct |
| ALHP x86-64-v3 Arch overlay | ADOPT | CPU-gated rebuilds of Arch packages; no performance or hardware-validation claim |
| Patched Mesa/kernel/audio stack | REJECT | No unresolved machine-specific requirement; ALHP rebuild flags are not an out-of-tree patch set |
| vkBasalt/low-latency Vulkan layer | REJECT | Optional effects/experimental behavior without a stated need |
| `asusd` + `asus-armoury` + `asus-shutdown` | ADOPT | Upstream ASUS control and safe firmware-mode application |
| PPD/tuned/TLP/auto-cpufreq alongside `asusd` | REJECT | Competing profile and EPP owners |
| RyzenAdj and LACT daemon | REJECT | Duplicate/brittle laptop power control |
| GameMode | REJECT | Current overlap outweighs unmeasured benefit |
| Cardwire | WATCH | Interesting replacement if eBPF switching stabilizes |
| supergfxctl | REJECT | Deprecated upstream; ASUS firmware attributes plus switcheroo-control cover the maintained baseline |
| switcheroo-control | ADOPT | Stable per-application hybrid-GPU baseline |
| Steam Deck-style fixed TDP control | REJECT | GA402 exposes different firmware interfaces |
| zram-generator | ADOPT | Small, upstream, bounded memory-pressure safety net |
| scx/ananicy/IRQ/sysctl tweaks | WATCH | Require reproducible GA402 benchmarks |
| Valve `steam-devices` rules + Steam Input | ADOPT | Covers Steam Controller and ordinary gamepads |
| InputPlumber/HHD/PowerStation | REJECT | Built-in handheld hardware is absent or unsupported |
| OpenGamepadUI | WATCH | Early optional shell; Steam Gamepad UI is the requested shell |
| SteamOS/OSTree updater and session switcher | REJECT | Wrong lifecycle for this mutable A/B repository |
| Forced gaming autologin | REJECT by default | Available as an explicit owner choice after testing |
| Audio quantum and network tuning | REJECT | No demonstrated problem and global side effects |

## Upstream research summary

The complete machine-readable record, including reviewed paths and decisions,
is in [`upstream-research.yaml`](upstream-research.yaml). All commits below were
reviewed on 2026-08-25.

| Project | Repository / branch | Reviewed commit | Commit date | Relevant result |
| --- | --- | --- | --- | --- |
| Bazzite | [ublue-os/bazzite](https://github.com/ublue-os/bazzite), `main` | [`f168cc5`](https://github.com/ublue-os/bazzite/tree/f168cc5280160bcebdde08e32721b025983faae4) | 2026-08-24 | Good desktop/deck separation and session ideas; immutable and handheld layers rejected |
| Nobara images | [Nobara-Project/nobara-images](https://github.com/Nobara-Project/nobara-images), `main` | [`ab64ebb`](https://github.com/Nobara-Project/nobara-images/tree/ab64ebbb238401a1c147413a549d96fb0046574d) | 2026-04-24 | Desktop/HTPC/handheld package separation |
| Nobara Steam packages | [steamdeck-edition-packages](https://github.com/Nobara-Project/steamdeck-edition-packages), `main` | [`98383d8`](https://github.com/Nobara-Project/steamdeck-edition-packages/tree/98383d8ba707b8db26453e68e70f2ee3d3cd7fb1) | 2026-03-21 | Robust session lifecycle, but too many distro/Deck hooks |
| ChimeraOS | [ChimeraOS/chimeraos](https://github.com/ChimeraOS/chimeraos), `master` | [`89b58ba`](https://github.com/ChimeraOS/chimeraos/tree/89b58ba69f52b4723a7bff472b9445b8b220c91f) | 2026-07-22 | Clean console-first concept; LightDM/image policy unsuitable for workstation |
| CachyOS Handheld | [CachyOS-Handheld](https://github.com/CachyOS/CachyOS-Handheld), `main` | [`120cebf`](https://github.com/CachyOS/CachyOS-Handheld/tree/120cebfa10d3dd15fd56be8606141d3105e7da52) | 2026-05-05 | Steam Deck forcing and HHD policy are handheld-only |
| CachyOS packages | [CachyOS-PKGBUILDS](https://github.com/CachyOS/CachyOS-PKGBUILDS), `master` | [`8cdc4e5`](https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/8cdc4e587cd2a8a9af8a84e4a4de96c9b5dd786f) | 2026-08-25 | Compatibility packages are ordinary; tuned kernel/scheduler is a product choice |
| ASUS Linux / asusctl | [OpenGamingCollective/asusctl](https://github.com/OpenGamingCollective/asusctl), `main` | [`9d53a53`](https://github.com/OpenGamingCollective/asusctl/tree/9d53a53c00c0bb955b73cc08156db1201b7905ad) | 2026-08-24 | Adopt sole `asusd` authority and upstream armoury interfaces |
| Cardwire | [OpenGamingCollective/cardwire](https://github.com/OpenGamingCollective/cardwire), `main` | [`7851b5d`](https://github.com/OpenGamingCollective/cardwire/tree/7851b5dbc58017186340c8c01955078d02491144) | 2026-08-21 | Early eBPF approach remains WATCH |
| OGC Gamescope session | [gamescope-session](https://github.com/OpenGamingCollective/gamescope-session), `main` | [`39c8351`](https://github.com/OpenGamingCollective/gamescope-session/tree/39c835136c242df16693431a55f1340280844e48) | 2026-08-21 | Adapt process ownership and two Xwaylands |
| OGC Steam session | [gamescope-session-steam](https://github.com/OpenGamingCollective/gamescope-session-steam), `main` | [`55e541a`](https://github.com/OpenGamingCollective/gamescope-session-steam/tree/55e541aa3adb80ee751220c886b9d133504f6e20) | 2026-08-03 | Adapt Gamepad UI shell; reject SteamOS helpers/Deck flags |
| Valve Gamescope | [ValveSoftware/gamescope](https://github.com/ValveSoftware/gamescope), `master` | [`b769931`](https://github.com/ValveSoftware/gamescope/tree/b769931518826e206894ec69aca678012a1655e1) | 2026-08-24 | Direct source of adopted CLI and Steam integration behavior |
| GameMode | [FeralInteractive/gamemode](https://github.com/FeralInteractive/gamemode), `master` | [`a74b810`](https://github.com/FeralInteractive/gamemode/tree/a74b8106a2236d1f2696aa44c93bc4c8ef13b42e) | 2026-06-15 | Useful actions, but conflicting power ownership here |
| Valve device rules | [ValveSoftware/steam-devices](https://github.com/ValveSoftware/steam-devices), `master` | [`22ec85e`](https://github.com/ValveSoftware/steam-devices/tree/22ec85e5ff5ea2e15c56d71a41bcbef46356cd60) | 2026-06-25 | Adopt distro-packaged controller permissions |
| zram-generator | [systemd/zram-generator](https://github.com/systemd/zram-generator), `main` | [`7855941`](https://github.com/systemd/zram-generator/tree/7855941d1a06257075e7f5a268b1f7bb702d5466) | 2025-05-25 | Adopt default bounded compressed swap |
| HHD | [hhd-dev/hhd](https://github.com/hhd-dev/hhd), `master` | [`9687f5e`](https://github.com/hhd-dev/hhd/tree/9687f5e459b513da2e49d993c49544d35146262c) | 2026-08-23 | Unsupported and irrelevant to GA402 built-in hardware |
| InputPlumber | [ShadowBlip/InputPlumber](https://github.com/ShadowBlip/InputPlumber), `main` | [`23f84b7`](https://github.com/ShadowBlip/InputPlumber/tree/23f84b78521a4e12f2ff7b16fa9e0dc03ccb1846) | 2026-08-21 | Virtual handheld-controller composition rejected |
| PowerStation | [ShadowBlip/PowerStation](https://github.com/ShadowBlip/PowerStation), `main` | [`350804f`](https://github.com/ShadowBlip/PowerStation/tree/350804f51c6de551b60df6ac57a5bb9ed42e3b6e) | 2026-02-21 | Generic handheld TDP daemon rejected for ASUS firmware path |
| OpenGamepadUI | [ShadowBlip/OpenGamepadUI](https://github.com/ShadowBlip/OpenGamepadUI), `main` | [`b149644`](https://github.com/ShadowBlip/OpenGamepadUI/tree/b149644f46b71e175a2ad223e84c18361596691e) | 2026-07-25 | Promising but early alternative shell remains WATCH |
| Local zephyrusctl experiment | [arvigeus/zephyrusctl](https://github.com/arvigeus/zephyrusctl), `main` | [`3d1b09c`](https://github.com/arvigeus/zephyrusctl/tree/3d1b09cafa30f46170c814a8e1ab6eea9c0d0a91) | 2026-07-09 | Valid goals; replace mismatched GPU ID, unbounded RyzenAdj, and auto-tune with measurement |

### Important differences

- Bazzite is the broadest integration layer and cleanly distinguishes desktop
  from Deck images, but many helpers exist for OSTree/bootc updates or a long
  list of handhelds. Its `powerstation-hardware` and `steamos-manager-hardware`
  lists do not include GA402.
- Nobara is a mutable general-purpose distribution with a large convenience
  package set. Its HTPC/handheld split is useful evidence; its session wrapper
  is robust but contains updater, device, and compatibility policy we do not
  need.
- ChimeraOS is closest to a purpose-built console. LightDM autologin, immutable
  image management, emulator bundle, and no-workstation assumptions are exactly
  why it should inspire the session boundary rather than be copied.
- CachyOS combines tuned packages/kernels with a separate handheld overlay. Its
  gaming meta-package mostly aggregates normal dependencies; performance claims
  are not a reason to transplant scheduler and sysctl policy piecemeal.
- Valve Gamescope and Steam device rules, plus ASUS's current upstream tools,
  provide the smallest primary-source implementation for this machine.

## Adopted ideas and local differences

### Login-manager gaming mode

Origin: ChimeraOS, Bazzite, Nobara, OGC Gamescope session packages.

Upstream uses a dedicated Gamescope login session, often with autologin and a
systemd user wrapper. This repository installs the same session boundary but
uses one shell wrapper, Plasmalogin selection, and no automatic updater or
autologin. The difference keeps failure behavior visible and preserves the
desktop as an equal first-class mode.

### Gamescope integration

Origin: Valve Gamescope and OGC/Nobara session configurations.

Current Gamescope `--steam` now sets the Steam integration capabilities itself.
The local wrapper adopts that interface, two Xwaylands, adaptive sync, and
Mangoapp. It replaces device quirk databases with dynamic connector discovery
and one DMI-scoped GPU preference. HDR remains explicit because correctness is
display-path dependent.

### Memory-pressure handling

Origin: Bazzite and upstream `zram-generator`.

Bazzite chooses a larger cap for a broad appliance image. This repository uses
the generator's conservative default half-RAM/4-GiB cap and adds no swappiness,
OOM, or memory-pressure daemon policy.

### ASUS control

Origin: current OGC `asusctl` documentation and services.

The local implementation follows upstream's `asusd`-only ownership option,
enables the shutdown helper, and masks PPD/tuned. Unlike a handheld overlay, it
does not invent Steam QAM sliders or translate a requested wattage into
unsupported Deck interfaces. ROG Control Center is the available UI for values
the GA402 firmware really exposes.

## Rejected and not applicable

These decisions should be revisited only when the stated premise changes.

| Feature/source | Why it is not integrated | Revisit when |
| --- | --- | --- |
| Bazzite OSTree/bootc updater, SteamOS update hooks | This repository is a conventional mutable Arch/Fedora A/B builder | the root becomes an immutable image |
| Steam Deck/Jupiter services and fixed TDP mechanisms | GA402 firmware and thermal design expose different ASUS interfaces | ASUS upstream adds a documented equivalent |
| HHD | Supported devices are Windows handhelds, not GA402 | HHD explicitly supports this laptop for a needed feature |
| InputPlumber | No built-in handheld controller needs combining/remapping | new integrated controls appear or Steam Input cannot solve a measured case |
| PowerStation/SteamOS Manager | Bazzite hardware gates omit GA402; duplicates ASUS control | GA402 becomes supported with safer functionality than `asus-armoury` |
| OpenGamepadUI session | Early shell adds InputPlumber/PowerStation dependency and duplicates requested Steam UI | it matures and a non-Steam shell becomes desirable |
| Cardwire | Early eBPF-LSM enforcement can deny GPU access; smart/hotplug behavior is still evolving | stable releases solve a measured dGPU-wake or switching problem |
| supergfxctl | ASUS upstream now calls it deprecated in favor of Cardwire; retaining the old daemon would add a third GPU-switching authority | only for a legacy capability unavailable through ASUS firmware attributes or a stable Cardwire |
| GameMode | Platform profile/governor actions conflict with `asusd`; benefit unmeasured | a benchmark shows benefit with power actions disabled |
| LACT/RyzenAdj | Extra privileged writers to laptop GPU/APU power state | ASUS firmware path proves insufficient and a safe tested profile exists |
| OGC kernel and patched Mesa | No required patch remains; increases packaging/UKI risk; the ALHP overlay does not reintroduce this patch set | a documented GA402 regression is fixed only there |
| CachyOS kernel, ananicy, scx | Integrated distro tuning without local A/B evidence | repeatable frame-time/power benchmarks justify it |
| vkBasalt and Vulkan low-latency layer | Effects/experimental layer installed for no stated game | a specific title/use case needs it |
| forced `-steamdeck` | Advertises handheld/SteamOS capabilities the G14 does not have | Valve provides a documented generic Steam Machine mode needing it |
| global Mesa/Proton/shader environment variables | Distro defaults already select RADV/runtime behavior | an upstream bug documents a scoped workaround |
| fixed 1600p/120 or 4K/75 Gamescope mode | Breaks the other display path and hotplug | a connector-specific quirk proves necessary |
| audio latency and gaming network tweaks | No measured problem; affect the whole workstation | diagnostics identify a specific fix |

### Required reintroduction conversation

`AGENTS.md` and the machine-readable ledger make the rejection table an active
guard, not historical prose. A future agent must not silently add a removed,
REJECT, or WATCH component. It must first show that the premise above changed,
then ask:

> Are you sure you want to reintroduce COMPONENT? It was removed because
> PRIOR_RATIONALE. The new evidence that may justify it is CHANGED_EVIDENCE,
> and the remaining risks or conflicts are RISKS.

In particular:

- Cardwire requires a measured dGPU runtime-suspend problem after render-node
  holders, external-display routing, and firmware modes have been checked, plus
  evidence that a stable Cardwire release solves that exact case.
- LACT requires a measured dGPU problem ASUS firmware cannot control and a
  tested configuration that does not keep the RX 6800S awake on battery.
- RyzenAdj requires absence of usable `asus-armoury` PPT controls and measured,
  recovery-tested GA402 limits; an arbitrary temperature target is insufficient.
- An OGC/patched kernel requires a named necessary patch absent from current
  Arch and Fedora kernels, not general gaming-performance claims.
- GameMode requires repeatable frame-time evidence with its overlapping
  platform-profile and governor actions disabled.

The user's confirmation is required even when an upstream gaming distribution
ships the component. If confirmed, the implementation and rationale ledger
must be updated together.

## Future investigation (WATCH)

- Test Gamescope HDR and SDR color handling on the exact Dell connector/cable;
  retain the opt-in only if both paths are correct.
- Compare Cardwire after its smart-mode and external-display behavior stabilize.
- Benchmark the stock scheduler against current `scx_lavd` on this 6900HS using
  frame-time percentiles, power, suspend, and desktop latency—not average FPS
  alone.
- Reconsider narrowly configured GameMode only for a demonstrated per-game
  scheduling/I/O issue.
- Watch OpenGamepadUI as a possible optional non-Steam shell, not as a required
  power/input layer.
- Track ASUS `asus-armoury` attributes and ROG Control Center support for this
  model as kernel and firmware updates expose more controls.
- Investigate a controller-accessible ASUS profile UI only if it can call the
  same `asusd` authority without adding a second power daemon.

## Refresh workflow

This repository has no established agent-skill directory or loader. A speculative
skill was therefore not added; this runbook and the YAML ledger are the durable
automation interface.

For a future gaming-stack refresh:

1. Read this document, `upstream-research.yaml`, and all current gaming/hardware
   modules before changing packages.
2. For each ledger source, fetch its recorded branch and compare
   `RECORDED_COMMIT..CURRENT_COMMIT`; record renames and force-pushes explicitly.
3. Focus on the recorded areas first, then search new files for Gamescope,
   Steam, Mesa, controller, power, ASUS, display, HDR, VRR, scheduler, and zram
   changes.
4. Check whether a previous rejection premise changed. Do not reopen a rejected
   feature merely because it remains present upstream.
5. Classify each substantial new feature as ADOPT, ADAPT, ALREADY COVERED,
   REJECT, or WATCH before implementation.
6. Keep policy distro-independent; use existing package specifications only for
   package-name/source differences.
7. Run all repository tests plus targeted session/YAML checks. Verify Arch and
   Fedora package names from their primary package indexes.
8. Update implementation, this README, every affected classification, and each
   source's branch/SHA/commit date/review date atomically.
9. Never claim GA402 runtime validation from source review; carry untested items
   into the checklist below.

## Manual hardware test checklist

Record kernel, Mesa, Gamescope, Steam, `asusctl`, firmware, connector, and EDID
versions with the result. A pass on one output or power source is not a pass on
the other.

### Read-only observation workflow

The installed command writes under
`~/.local/state/system/g14-observations/` by default. It reads sysfs and normal
diagnostic commands; it does not start a load, change a profile, or require
root. Its normal snapshot and recorder skip DRM/VA-API/Vulkan probes and read
dGPU hwmon values only when runtime PM already reports the RX 6800S active, so
the observer does not keep waking a suspended dGPU merely to measure it. First
capture the idle/control state:

```bash
system-g14-observe snapshot > ~/g14-snapshot.txt
```

On AC, a separate `snapshot --active-probes` captures DRM, VA-API, and Vulkan
capabilities. It may briefly wake the dGPU, so do not run it immediately before
a battery measurement; wait for runtime PM to settle again.

If `zephyrusctl.timer`, LACT, Cardwire, PPD, or tuned is active in that report,
disable it for the controlled baseline so it cannot change the experiment. Do
not run `powertop --auto-tune`; `powertop` may be used interactively to inspect
wakeups, but GPU monitoring programs should not be left open during the battery
run because opening a render node can itself keep the dGPU active.

For a video-playback battery baseline:

1. Start from a known charge, unplug AC, use the internal panel, choose the
   firmware's Quiet battery policy, fix brightness, volume, network, refresh
   rate, player, and local video file, and close unrelated programs.
2. Confirm hardware decoding for the file/API with `vainfo` and the player's
   own diagnostic overlay. Merely installing VA-API is not proof the current
   codec is decoded in hardware.
3. Record at least 30 minutes of the actual movie:

   ```bash
   system-g14-observe record --label battery-video-baseline --duration 1800 --interval 5
   ```

4. Inspect `summary.txt`, `samples.csv`, and `metadata-before.txt`. A dGPU that
   is `active` throughout the internal-panel run is a lead: inspect the recorded
   render-node users and processes before considering Cardwire. If it suspends,
   compare hardware decoding, high-refresh versus 60 Hz, brightness, CPU-heavy
   processes, and `energy_full` versus `energy_full_design` one variable at a
   time. The recorder estimates runtime from measured power and remaining
   energy; two hours is only possible when their ratio supports it.

For a thermal gaming baseline, do **not** begin with `stress-ng` or a combined
synthetic CPU/GPU burn on a machine known to shut down. Use the same reproducible
game/scene, resolution, frame limit, and AC state, with firmware tuning disabled
unless a previously configured value is being explicitly tested:

```bash
system-g14-observe record --label gaming-baseline --duration 900 --interval 2
```

Keep its terminal visible and stop the game early if temperatures continue to
rise abnormally or fan response is missing; the objective is diagnosis, not
reproducing a hard shutdown. Compare profile, CPU temperature/fan, dGPU edge and
junction temperatures, dGPU power/fan, and clocks. High fans with both CPU and
dGPU hot suggests the shared power/thermal envelope needs a conservative
firmware-supported bound. A cool or bounded CPU with rising GPU junction
temperature means a RyzenAdj CPU target would not solve the failure. High
temperature with unexpectedly low fans points first to profile, curve, sensor,
firmware, or physical cooling-service investigation.

After any unexpected shutdown, preserve the unfinished observation directory
and, after reboot, capture the previous boot before it ages out:

```bash
journalctl -b -1 -k --no-pager > ~/g14-previous-kernel.log
```

Only after these baselines should one variable be tested at a time—for example
Balanced versus Performance, a frame cap, or boost policy. Do not select exact
PPT or fan-curve values until `asusctl armoury list`, supported curve ranges,
and the recordings are available. Record firmware/BIOS version and ambient
conditions with every comparison.

- [ ] **Desktop Steam:** launch a native/Vulkan title and a Proton title.
  Expect RADV, working audio/input, and no overlay unless explicitly requested.
  Inspect with `vulkaninfo --summary`, Steam's runtime log, and `journalctl --user`.
- [ ] **Enter gaming mode:** choose **Steam Gaming Mode** at Plasmalogin. Expect
  Gamepad UI on one display with controller navigation. Inspect the previous
  boot/session with `journalctl --user -b` and `journalctl -b _COMM=gamescope`.
- [ ] **Exit gaming mode:** choose **Exit Steam**. Expect Gamescope to terminate
  and Plasmalogin to reappear; it must not relaunch in a loop.
- [ ] **Steam Controller:** test dongle/Bluetooth pairing, wake/reconnect, Steam
  Input layout, game input, and complete Gamepad UI navigation. Check
  `steam-devices`, `udevadm info`, `lsmod | grep hid_steam`, and Steam controller
  settings if input is missing.
- [ ] **Ordinary gamepad and Steam Deck use:** verify the intended transport or
  Remote Play path without InputPlumber/HHD. Expect no duplicate virtual pad.
- [ ] **Internal panel:** boot gaming mode undocked. Expect the internal
  preferred mode, correct orientation/scaling, and no RX 6800S hard failure in
  integrated mode. Check `cat /sys/class/drm/card*-*/status` and `drm_info`.
- [ ] **External display:** connect the Dell before login. Expect it to be
  preferred and its native 4K mode/available refresh selected. Verify the real
  connector and modes under `/sys/class/drm/*/modes`; override only if needed.
- [ ] **VRR:** confirm the display OSD and Gamescope/DRM state while frame rate
  varies inside the VRR range. Expect no claim of VRR merely from a 75 Hz mode.
- [ ] **HDR:** first confirm SDR colors with HDR off. Then set
  `SYSTEM_GAMING_HDR=1`, use a known HDR title/test, and verify display OSD,
  highlights, blacks, and SDR content. Revert immediately if SDR is washed out.
- [ ] **Frame limiting:** set Steam's per-game limiter at useful divisors/rates
  and inspect Mangoapp frame-time graphs. Expect no global cap from this repo.
- [ ] **Mangoapp/MangoHud:** toggle the Gamescope performance view; separately
  launch a desktop game with `mangohud %command%` and toggle with Right Shift+F12.
- [ ] **Suspend/resume:** test from desktop and gaming mode, once internal-only
  and once docked, with a game running. Expect graphics, audio, network, and
  controllers to recover without restarting the display manager.
- [ ] **AC to battery and back:** watch `asusctl profile get`, battery discharge,
  clocks, and noise. Expect `asusd` policy changes without PPD/tuned becoming
  active. Check `systemctl is-active asusd power-profiles-daemon tuned`.
- [ ] **ASUS controls:** record `asusctl info --show-supported`, `asusctl armoury list`,
  profile list, and fan-curve support. Change one supported value at a time and
  confirm it survives/returns as documented. Do not infer Deck-style wattage.
- [ ] **Thermals/fans:** use the bounded real-game observation above, initially
  10–15 minutes on AC. Stop on abnormal temperature rise or fan behavior; do
  not treat survival of a stress test as the goal.
- [ ] **GPU mode/application offload:** test hybrid per-app launch and the ASUS
  firmware modes actually reported. Confirm queued changes apply on shutdown
  and that external ports still work in the chosen mode.
- [ ] **Audio:** verify speakers, headphones, HDMI/DisplayPort audio, and any
  controller audio before and after hotplug/resume. Use `wpctl status`; expect
  WirePlumber, not a gaming script, to own routing.
- [ ] **Zram pressure:** confirm `zramctl` and `swapon --show`; during a memory
  spike expect bounded compressed swap, not an immediate OOM. Do not test
  hibernation against zram.

## Validation boundary

Repository tests can validate Bash/config syntax, allowed package declarations,
file references, dry-run session construction, and ledger structure. Upstream
source review supports the expected behavior described above. Actual DRM lease,
VRR, HDR, suspend, thermals, firmware attributes, controller radio behavior,
and AC/battery transitions require the GA402 checklist and are not considered
tested until recorded on the machine.
