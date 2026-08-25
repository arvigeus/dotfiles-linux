# Selectable gaming session

The gaming module adds a console-style session without making the machine act
like a Steam Deck. KDE's Plasma Login Manager remains in charge, autologin is
not configured, and Plasma remains an ordinary Wayland desktop. The session
picker exposes:

- **Plasma (Wayland)**: the minimally provisioned KDE desktop.
- **SteamOS (gamescope)**: Steam Gamepad UI in a dedicated Gamescope session.
- **Steam Big Picture Plus**: the same session with OpenGamepadUI as an overlay.

Selecting **Switch to Desktop** in Steam shuts down Steam and returns to Plasma
Login Manager. It does not alter the default session or arrange an automatic
login; select Plasma and sign in normally.

## Component provenance

| Component | Arch | Fedora | Runtime policy on this laptop |
| --- | --- | --- | --- |
| Steam, Gamescope, GameMode, MangoHud, vkBasalt | Official repositories | Fedora and RPM Fusion | Available normally |
| Gamescope session | OGC snapshot from Chaotic-AUR | Terra | Login-manager session |
| Steam Gamepad UI session | OGC snapshot from Chaotic-AUR | Terra | Login-manager session |
| InputPlumber | Upstream binary AUR package | Terra | Installed, not globally enabled |
| PowerStation | Checksum-pinned upstream 0.8.1 local recipe | Terra | Installed, disabled |
| OpenGamepadUI | Upstream binary AUR package | Terra | Optional overlay session |
| Vulkan low-latency layer | Upstream AUR package | Terra | Installed as Bazzite's current optional Vulkan layer |
| SteamOS-Manager | Pinned OGC PowerStation-fork recipe | Terra's equivalent build | System and user daemons enabled; SDDM-only API disabled |
| Cardwire | OGC Arch repository | Terra | Enabled, initially in safe hybrid mode |
| ASUS controls | OGC Arch repository | Terra | `asusd`, ROG Control Center, and PPD enabled |
| Kernel | OGC `linux-ogc` | OGC Fedora RPM artifact | Both final UKIs select OGC |

Arch adds the narrowly scoped OGC and Chaotic-AUR repositories, but never adds
CachyOS, ChimeraOS, or another distribution's base repository. OGC supplies
`linux-ogc`, `asusctl`, ROG Control Center, and Cardwire. Current OGC
Gamescope-session snapshots come explicitly from
Chaotic-AUR. Official Arch repositories retain higher Pacman priority, and OGC
is ordered above Chaotic-AUR to protect any future package overlap. The AUR
plugin installs `paru` explicitly from Chaotic-AUR; it does not build `paru` or
depend on the tracked-PKGBUILD plugin.

Ordinary `arch:aur/<name>` requests still build from the AUR. Tracked recipes below
`packages/arch/` are used only through the explicit `arch:pkgbuild/<name>` route;
they do not silently override an AUR or repository package. PowerStation 0.8.1
uses that route because the AUR stable binary is still 0.7.0, and the OGC
SteamOS-Manager fork uses it because no Arch package currently exists. Cardwire
comes directly from OGC; no redundant local recipe is retained.

Fedora uses Terra only for the new gaming-session daemons and ASUS/Cardwire
packages for which Fedora does not provide equivalents. Steam comes from RPM
Fusion; the ordinary gaming packages remain Fedora packages.

## First start

After a successful rebuild and reboot:

1. Sign into Plasma once and start Steam to finish its first-run download and
   sign-in. This is easier to debug than doing first-run work in Gamescope.
2. Log out, open Plasma Login Manager's session menu, and choose **SteamOS
   (gamescope)**.
3. Use **Steam Big Picture Plus** only when testing the OpenGamepadUI quick
   menu. InputPlumber may need to be started first as described below.

The GA402RK override enables Adaptive-Sync, exposes 60/120 Hz choices, treats
the panel as internal, and prefers the RX 6800S (`1002:73ef`) for both gaming
sessions. Resolution is left to Gamescope/DRM detection, so the configuration
does not force an internal render resolution.

To choose another renderer interactively, run this in Plasma:

```bash
export-gpu
```

It writes a later user override below `~/.config/environment.d/`. Choose the
Radeon 680M for a low-power experiment or the RX 6800S for normal gaming. Remove
`~/.config/environment.d/00-vulkan-device.conf` to return to the provisioned
GA402RK default.

## Cardwire and GPU modes

Cardwire replaces `switcheroo-control`; it implements the Switcheroo D-Bus
interface while also being able to prevent accidental dGPU wakeups. Its first
start uses **hybrid** mode, in which neither GPU is blocked:

```bash
cardwire list
cardwire get
cardwire set hybrid
```

Use `cardwire set integrated` for desktop battery life. Return to hybrid before
starting the provisioned gaming session, because that session explicitly asks
Gamescope for the RX 6800S. Smart mode is available but remains an upstream
work in progress; inspect its application policy before relying on it.

Cardwire requires Wayland and a kernel with the BPF LSM active. Current stock
Arch and Fedora kernels are supported upstream. Diagnose the booted machine
with:

```bash
systemctl status cardwired.service
cat /sys/kernel/security/lsm
cardwire manager status
```

The final command should work after login, and the LSM list should contain
`bpf`.

## InputPlumber and PowerStation

InputPlumber and PowerStation are installed so the complete stack is available,
but they are not global laptop defaults. PowerStation follows Bazzite's
non-handheld policy; InputPlumber is made opt-in because the G14 has no built-in
gamepad. This avoids creating duplicate controllers or competing with
ASUS/Plasma power management.

InputPlumber's own DMI/udev rules can start it automatically on supported
handhelds; the GA402 is deliberately absent from that list. Start it manually
before testing the OpenGamepadUI overlay or advanced controller remapping:

```bash
sudo systemctl start inputplumber.service
journalctl -u inputplumber.service -f
```

If Steam sees both a physical and virtual copy of a controller, stop
InputPlumber and use Steam Input directly:

```bash
sudo systemctl stop inputplumber.service
```

PowerStation is primarily useful for handheld TDP controls. On this G14,
`asusctl` and Power Profiles Daemon remain the defaults. It can still be tested
without making it persistent:

```bash
sudo systemctl start powerstation.service
sudo systemctl stop powerstation.service
```

## SteamOS-Manager boundaries

Both SteamOS-Manager daemons are installed so supported Steam client APIs are
available. Its current session-management implementation writes SDDM
configuration, while Plasma Login Manager uses a different configuration and
service. The project therefore does **not** install SteamOS's `holo.conf` SDDM
marker. SteamOS-Manager does not expose that session-management/autologin API
and cannot silently turn the laptop into a console appliance. Inspect the
daemons after logging into a gaming session with:

```bash
systemctl status steamos-manager.service
systemctl --user status steamos-manager.service
```

The upstream Steam session already implements **Switch to Desktop** by shutting
Steam down. That ends the Gamescope login session and returns to Plasma Login
Manager. A compatibility helper also recognizes `plasmalogin.service` if Steam
asks to restart the legacy display-manager helper path. One-click automatic
switching between preselected sessions is deliberately unavailable; log out and
choose the other session instead.

Current Bazzite Deck images still remove Plasma Login Manager and install SDDM
because their console autologin and one-shot switching machinery depends on it.
This project chooses the newer KDE login manager and the simpler manual-session
boundary requested for the laptop.

## In-place and A/B updates

Steam's OS-update command now checks and upgrades the active root with its
native package manager:

- Arch checks repository updates safely with `checkupdates`, includes AUR
  update checks, and upgrades repository and AUR packages through `paru -Syu`.
- Fedora checks with `dnf check-upgrade` and upgrades with `dnf upgrade`.

The command follows Steam's duplicate-detection/check protocol and elevates via
the session package's Polkit helper. Kernel updates also refresh the direct-boot
UKI for the running slot: Arch installs a Pacman post-transaction hook, and
Fedora installs a `kernel-install` plugin plus an explicit post-update fallback.
The inactive root and its UKI are not touched.

The native updater and Plasma Login Manager compatibility helper live below
`/usr/local/libexec/system`. Package-owned Steam helper paths are restored
after Steam-driven upgrades, after relevant Pacman transactions, and by
`systemd-tmpfiles` at boot, so a session-package upgrade does not permanently
reintroduce its Arch-only updater or SDDM-only restart helper.

The checksum-pinned local PowerStation and SteamOS-Manager recipes have no
remote repository to update them in place. They remain at their selected build
until the recipes in this project are updated and a clean rebuild is run; all
official, OGC, Chaotic-AUR, Terra, and ordinary AUR packages participate in the
native update path.

This is intentionally separate from `rebuild.sh`. Use Steam or the native
package manager when keeping the current root, and use `rebuild.sh` when a clean
opposite-slot generation is wanted. An in-place update has ordinary mutable
distro semantics; it does not gain the atomic rollback guarantees of the A/B
rebuild workflow.

## Deliberate omissions

The build selects OGC kernels on Arch and Fedora while retaining Fedora's stock
kernel as an installed recovery fallback. It keeps stock Mesa and Gamescope and
does not install a CachyOS kernel, a patched Mesa stack,
`sched_ext` policy, `bpftune`, dmemcg boosters, Steam Deck firmware
helpers, Bazzite's image updater, or a console autologin service. Those pieces
either belong to an image-based distribution, replace the UKI-owning kernel
backend, or are hardware-specific handheld tuning rather than requirements for
a selectable laptop gaming session.

This provisioning has been source-reviewed but still needs a real GA402RK
runtime pass. In particular, test suspend/resume, internal and external display
routing, audio, controller hotplug, in-place kernel updates, and return to
Plasma Login Manager before depending on the session day to day.

## Research anchors

- [Bazzite Deck 44 announcement](https://universal-blue.discourse.group/t/bazzites-biggest-update-deck-44-has-launched-happy-birthday-to-universal-blue/12373)
  and [Bazzite source](https://github.com/ublue-os/bazzite)
- [OGC Gamescope session](https://github.com/OpenGamingCollective/gamescope-session)
  and [OGC Steam session](https://github.com/OpenGamingCollective/gamescope-session-steam)
- [InputPlumber](https://github.com/ShadowBlip/InputPlumber),
  [PowerStation](https://github.com/ShadowBlip/PowerStation), and
  [OpenGamepadUI](https://github.com/ShadowBlip/OpenGamepadUI)
- [OGC SteamOS-Manager fork](https://github.com/OpenGamingCollective/steamos-manager)
  and [Cardwire](https://github.com/OpenGamingCollective/cardwire)
- [OGC Arch packaging](https://github.com/OpenGamingCollective/ogc-arch-packaging),
  enabled only for the OGC userspace packages listed above
- [Plasma Login Manager](https://invent.kde.org/plasma/plasma-login-manager)
