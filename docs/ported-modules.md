# Ported modules

This inventory maps the former `linux-bootc/provision/modules` tree to the
clean-root execution model. Every active script is an independent Bash process,
sources `lib/module.sh`, and relies only on its own packages plus explicitly
sourced helpers in `lib/`. The old `modules.conf`, command shims,
reconciliation state, bootc branches, and deploy machinery are not used.

The paths below are relative to `modules/` unless stated otherwise.

## Ported for Arch and Fedora

- `apps/browsers/{chromium,firefox,tor-browser,zen}.sh`
- `apps/communication/{discord,telegram,whatsapp}.sh`
- `apps/media/graphics/{gimp,photopea}.sh`, `apps/media/music/fooyin.sh`,
  `apps/media/tools/{ffmpeg,image,mkvtoolnix,pdf,subtitles}.sh`, and
  `apps/media/video/{kodi,mpv,syncplay,vlc,youtube}.sh`
- `apps/office/{docs,productivity}.sh` and `apps/torrents/qbittorrent.sh`
- `base/{archive,bash,config-parsers,shell,utils}.sh`
- `desktop/fonts.sh` and `desktop/integration/electron.sh`
- `dev/databases/sqlite.sh`
- `dev/editors/{micro,nano,vscode,zed}.sh`
- `dev/languages/{deno,nodejs,rust}.sh`
- `dev/tools/{api-client,bat,delta,devtoolbox,distrobox,fastfetch,git,just,lsd,meld,mise,podman,shell}.sh`
- `gaming/compat/{proton,wine}.sh`,
  `gaming/games/{diablo-1,nethack,red-alert-2,roblox}.sh`, and
  `gaming/launchers/{heroic,lutris,umu-launcher}.sh`
- `hardware/cpu/{amd,tools}.sh`, `hardware/gpu/amdgpu.sh`,
  `hardware/devices/zephyrus.sh`,
  `hardware/peripherals/{input-tools,logitech}.sh`, `hardware/firmware.sh`, and
  `hardware/storage/ssd.sh`
- `system/network/{tools,wireless}.sh`
- `system/package/{appimage,flatpak}.sh`
- `system/performance/{geekbench,gravity-mark,tools}.sh`
- `system/security/{sudo,ufw}.sh`
- `system/storage/rclone.sh`
- `system/virtualization/virt-manager.sh`

## Arch-only

- `dev/tools/make.sh` writes makepkg parallel-build configuration.
- `system/package/distro/arch.sh` configures Pacman, multilib, reflector, and
  pkgstats.

## Fedora-only

- `apps/media/codecs.sh` configures the RPM Fusion multimedia package set.
- `dev/editors/fresh.sh` installs Fresh from Terra; the former Arch AUR path is
  not available through the core Pacman interface.
- `system/package/distro/fedora.sh` enables RPM Fusion and Terra.

## Flatpak installation

`lib/flatpak.sh` provides `flatpak_install`. Repository plugins register their
system remote and invoke `flatpak install --system -y --noninteractive` inside
the candidate chroot. Modules run as root, so Flatpak writes directly to the
system installation without requiring a graphical session, user session bus,
or `flatpak-system-helper`. Applications, runtimes, dependencies, and branches
are resolved by Flatpak from the selected remote.

## Ported with limitations

- Chromium is installed natively and Google Chrome is declared as a system
  Flatpak. Chromium extension policy is global under `/etc/chromium`.
- Firefox extensions are global, while profile preferences and custom search
  engines are staged in `/etc/skel` because Firefox has no equivalent global
  search-engine format.
- Fedora FiraCode Nerd Font files are downloaded from the latest upstream
  GitHub release. Arch uses the `nerd-fonts` package.
- Nano syntax highlighting uses the native Arch package and the latest upstream
  release on Fedora. The shared `/etc/nanorc` is owned by the target project's
  existing `modules/tools/editor/nano.sh` module to avoid conflicting writers.
- Fedora Deno uses the latest upstream x86-64 release binary under
  `/usr/local/bin`.
- Fedora Node.js omits Bun because no native package was confirmed and a
  user-local installer is inappropriate for the candidate root.
- VS Code extensions are not installed. They are user-local packages and the
  former post-deploy extension service is intentionally absent. Merged settings
  are staged in `/etc/skel`.
- mpv shaders and plug-ins are installed globally from upstream. uosc is built
  independently with temporary Go dependencies. Latest upstream content is not
  reproducibly pinned.
- Modules that retain the former `repo_health` checks source
  `lib/repo-health.sh`. Archived, missing, or stale repositories warn;
  transient API/rate-limit failures do not block the build unless a caller
  explicitly requests `--quit`.
- VLC's pause-click plug-in is installed natively on Fedora and through the
  core `pacman_install` AUR interface on Arch. Fresh similarly uses Terra on
  Fedora and `fresh-editor-bin` through `pacman_install` on Arch.
- Distrobox includes the BoxBuddy Flatpak, Podman includes the Pods Flatpak,
  and yt-dlp includes the Parabolic Flatpak. Podman still does not enable a
  user socket without a running user manager.
- GIMP is preinstalled with packaged Flatpak plug-ins and Batcher is staged in
  `/etc/skel`. Fooyin receives portable defaults with the machine-specific music
  path removed. Kodi resolves and stages the latest configured add-ons and
  dependencies at build time; upstream changes or outages can therefore fail a
  rebuild or change its output.
- Roblox is preinstalled, but its former user-scoped input-device override is
  omitted because the build has no user Flatpak installation.
- UFW is enabled with persistent default-deny/default-allow policy without
  probing the build host's kernel. No interface-specific rules are applied.
- libvirt enables IP forwarding and `libvirtd`; the former hard-coded `wlan0`
  UFW rules were removed.
- fwupd metadata refresh is enabled, but firmware updates are never run against
  live build-host hardware.
- AppImage support uses checksum-verified AppManager 3.7.3 source and does not
  require FUSE 2. Fedora lacks DwarFS extraction in this port, and neither
  distribution gets zsync2 delta updates because a suitable native package was
  not confirmed.
- Fresh is Fedora-only. Zed on Fedora depends on Terra. UMU Launcher on Fedora
  depends on the Bazzite COPR. Each affected module enables its own repository
  and does not depend on repository-module ordering.

## Latest-at-build modules

Kodi add-ons, GIMP Batcher, browser extensions/search data, several mpv assets,
Fedora Deno, Nerd Fonts, Nano highlighting, and GravityMark intentionally track
latest upstream content. These modules are not reproducible: upstream changes,
removals, or outages can alter or fail a clean rebuild. Downloads fail on HTTP
errors and use temporary directories, but not every upstream publishes a
checksum suitable for verification.

No user Flatpak installation, systemd user manager operation, or first-login
deployment framework was introduced. Safe `~/.var/app` defaults are staged
under `/etc/skel` and handled by the existing home reconciliation model.

## Disabled for other reasons

- Web applications use stateless global launchers from `lib/webapp.sh`;
  each launcher creates its isolated Chromium profile lazily in the invoking
  user's XDG data directory.
- Machine-selected hardware is now guarded directly: AMD CPU and GPU modules
  inspect native CPU/PCI IDs, Zephyrus checks DMI, and Logitech checks USB vendor
  ID. Disconnected Bluetooth-only Logitech devices intentionally do not opt in.
- Zephyrus installs userspace support only on Arch. The backend owns the kernel
  and UKI, so the module does not replace it with `linux-g14`.
- `system/package/brew.sh`: the patched, world-writable nonstandard Homebrew
  prefix is not a safe system-level installation.

## Obsolete in the clean-root model

- `modules-disabled/base/init/arch.sh` records that the former Arch init module
  declared no state; Arch base initialization belongs to the backend.
- `modules-disabled/system/package/webget.sh`: the webget executable and its
  reconciliation/deploy lifecycle are absent. A small stateless
  `lib/webapp.sh` now generates Photopea, NetHack, and Chrono Divide
  launchers instead.
- The custom Yaak AppImage path is obsolete; Yaak is now a system Flatpak.
- `modules-disabled/gaming/games/age-of-empires.sh`: comment-only placeholder
  that declared no state.
- Package state lists, file tracking, image digest state, transparent command
  shims, `modules.conf`, and first-boot deployment are intentionally absent.

## Package-name and repository assumptions

These modules target current x86-64 Arch and Fedora roots, matching the core
backend. Package names were retained where the former project already supplied
native mappings. Notable assumptions requiring VM confirmation are:

- Fedora provides `syncplay`, `pnpm`, `lsd`, `shfmt`, `git-delta`,
  `podman-compose`, `docker-compose`, `wireless-regdb`, `wavemon`, `ufw`, and
  the listed AppManager build `-devel` packages.
- RPM Fusion provides Fedora `ffmpeg`, `vlc-plugins-all`, `unrar`, and
  `vlc-plugin-pause-click`.
- Terra provides Fedora `zed` and `fresh`.
- The Bazzite COPR provides Fedora `umu-launcher` and `ryzenadj`; the LACT COPR
  provides Fedora `lact`.
- Arch provides `bun`, `pnpm`, `just-lsp`, `zed`, `umu-launcher`,
  `vlc-plugins-all`, `dwarfs`, and the `nerd-fonts` metapackage.
- The official Microsoft VS Code and mise RPM repository definitions remain
  compatible with DNF5.
- Fedora provides `logiops`; the Arch Logitech module builds upstream logiops
  with CMake because no native repository package was assumed.
- `pacman_install` supports current AUR packages `vlc-pause-click-plugin` and
  `fresh-editor-bin`.
- Native Flatpak is version 1.17 or newer and supports `flatpak preinstall`;
  Flathub's stable and beta collection IDs remain `org.flathub.Stable` and
  `org.flathub.Beta`.

These are source-reviewed assumptions, not runtime validation claims.

## Core interface assumptions

The port assumes the backend contract requested for the parallel core work:
`pkg_install`, `pkg_is_installed`, `pkg_remove`, `pkg_from_source`,
`pacman_install`, `file_write`, `file_append`, `file_install_tree`, and all
listed GitHub helpers.

At the time of this port, `pkg_from_source`, file helpers, package helpers, and
GitHub helpers are present in the checked-out target. `pacman_install` remains
an interface item for the parallel backend agent and is now used by the Arch
VLC and Fresh modules.

## Validation status

No module, package manager, source build, test suite, VM, or graphical/runtime
operation was executed on this resource-constrained development machine.
Validation is limited to static source review and diagnostics. Use disposable
Arch and Fedora VMs and the manual flows in the project README for runtime
validation.
