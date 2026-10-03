# Desktop profiles and Python development

`HOST_PROFILE` selects `hosts/<profile>.sh`, independently of the machine's
`HOSTNAME`. `DESKTOP` is `plasma` or `hyprland`; both are saved with the other
non-secret settings in `/etc/system/config`. Older configurations without these
keys use their existing hostname as the profile and default to Plasma.

The installer passes desktop/profile values to every module's plan, apply and
healthcheck process, including preflight. `desktop/module.sh` selects the
chosen implementation alongside shared Electron defaults and fonts. A plan
records each package's declaring leaf in `/var/log/system/package-plan.tsv`,
so its owner is directly visible.

| Selection | Desktop owner | Login owner | Desktop-specific media |
| --- | --- | --- | --- |
| Plasma | `desktop/plasma` | Plasma Login Manager, existing autologin policy | common media module includes Kodi |
| Hyprland | `desktop/hyprland` | greetd/tuigreet, password login | Kodi skips Hyprland |

mpv, Syncplay, VLC, YouTube and other media leaves stay in common composition.
Kodi explicitly requires mpv for its configured external-player integration.
Dolphin is also a Zephyrus application dependency; its presence does not imply
a Plasma session. Gaming remains a separate selectable session and does not
own the ordinary desktop's display policy. No rejected power or GPU backend is
added by Hyprland.

## Bootstrap and rebuild

Disk, host profile and desktop use small numbered Bash menus. Username, timezone,
locale and keymap retain Enter defaults (`user`, `UTC`, `en_US.UTF-8`, `us`).
Hostname defaults to the selected profile, with underscores changed to hyphens.
The summary includes disk size/model,
profile, hostname, desktop and the encrypted two-slot layout. Destruction still
requires typing the full disk path. `--yes` is an explicit automation opt-in;
it does not supply encryption or login passwords.

All answers have `--disk`, `--host-profile`, `--hostname`, `--desktop`,
`--username`, `--timezone`, `--locale`, and `--keymap` options and corresponding
`SYSTEM_DISK`, `SYSTEM_HOST_PROFILE`, etc. environment overrides. CLI values win.
`--non-interactive` requires disk/profile/desktop overrides and fills the other
answers from defaults. Native LUKS/password prompts still need a terminal.

```bash
sudo ./bootstrap.sh --non-interactive --disk /dev/vda --host-profile vm \
  --desktop hyprland --hostname vm-hyprland --healthchecks
```

Normal rebuilds reuse the installed selection. To switch desktops, build the
inactive root explicitly:

```bash
sudo ./rebuild.sh --desktop hyprland --healthchecks
```

Existing Arch installations made before the base-package fix may first need
`sudo pacman -S --needed arch-install-scripts` to supply `pacstrap` on the running
root. New roots include it. Rebuild deliberately does not install prerequisites
into the active root automatically.

That candidate persists the new choice; the running slot retains its old
configuration. The old desktop's packages are absent from the newly built root,
though user-modified defaults can remain in persistent home according to the
normal home reconciler. The small Hyprland session configuration is retained
in shared home when switching to Plasma so the fallback root can still start
Zephyrus; those files do not install or activate Hyprland in the Plasma root.
Boot the candidate and confirm its session before
rebuilding the fallback slot.

## Zephyrus installation

Hyprland is **currently Arch-only**. Fedora Plasma remains supported; Fedora
Hyprland requests fail before disk destruction. Zephyrus uses current Hyprland
Lua/native scrolling and a Qt 6 QML terminal. Fedora's published runtime packages
lag those requirements; enabling it needs compatible packages and a booted
Fedora session test, not just renamed dependencies.

The `desktop/hyprland` leaf declares Hyprland, Quickshell, Qt/QML, Python runtime,
portals, hyprpolkitagent, lock/idle, audio, connectivity, UPower, terminals, fonts
and display helpers. It builds the latest public `arvigeus/zephyrus-shell` HEAD as a
native `zephyrus-shell` package under `/usr/share/zephyrus-shell`. The source tree
is retained coherently; `/usr/share/zephyrus-shell/REVISION` records its commit.
It never uses the sibling development checkout or executes `setup-system.sh`.

The Zephyrus recipe uses an unpinned Git source. Every build fetches the current
public default-branch HEAD; `pkgver()` derives its date, revision count and hash
from the checkout, and `REVISION` records the full commit actually packaged.
`packages/update.sh` preserves this behavior without pinning a commit or archive.
The resolved recipe metadata is retained under
`/var/log/system/package-recipes/desktop/hyprland`. Other recipes resolve their
upstream versions in a disposable recipe copy. A rebuild can therefore advance
Zephyrus; it is not a reproducible lock of all upstream versions. The previous
root retains its prior package for rollback.

The home defaults contain a Lua shim calling
`/usr/share/zephyrus-shell/hyprland/hyprland.lua`, lock/idle configuration links, and
Hyprland/GTK portal routing and standard systemd user services. UWSM owns
the session lifecycle; greetd launches the UWSM Zephyrus session. Audio, networking and Bluetooth remain owned by their hardware modules.
DDC uses packaged I2C permissions plus user membership. Profiles use the
existing asusd owner on ASUS hardware, with an active PPD fallback elsewhere.
GPU selection uses switcheroo-control. No fan or PPT values are claimed safe
without a physical load test. Shell fixes are published in the companion
repository and consumed directly, without a local session patch. Provider URLs and the private
`zephyrus-shell/media.json` remain user configuration outside the package.

The self-contained desktop companion set and integration choices are described in
[Hyprland desktop kit](hyprland-desktop-kit.md).

Healthchecks verify commands, the installed revision, shim, Python imports,
polkit unit and enabled login manager. Session startup still requires a live
login test. See [VM validation](vm-validation.md).

## Python development

`dev/languages/python` installs native Python, `uv`, `ruff`, `ty`, and pip on
Arch/Fedora. Use uv for projects, environments, tools and packages; Ruff handles
linting, import sorting and formatting; ty handles type checking/language-server
work. pip remains for compatibility, not the primary workflow. No global
Black/isort/Flake8 stack or universal project configuration is imposed.
Healthchecks verify the commands and Python's pip module. Existing XDG REPL
history and pip-cache defaults remain.

## Firefox configuration

Firefox comes from the distribution repository. Arkenfox comes from
`arch:aur/arkenfox-user.js`; the official Arch package index has no match.
Chaotic currently carries only `arkenfox-user.js-git`, so the stable AUR
package is used instead of that development build.
On Fedora, the official catalog, COPR project search, and Terra's complete
`frawhide` package tree had no Arkenfox match on 2026-10-02, so
`fedora:rpmspec/arkenfox-user.js` remains the fallback. Its updater resolves the
latest stable upstream release automatically before every install/rebuild.
Both packages install `/usr/share/arkenfox-user.js/user.js`.

`modules/browsers/firefox.sh` checks that template before writing configuration,
then generates `arkenfox.cfg` and `defaults/pref/arkenfox.js` under the native
Firefox installation (`/usr/lib/firefox` on Arch, `/usr/lib64/firefox` on Fedora).
Mozilla's [AutoConfig](https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig)
sets Arkenfox preferences plus local overrides on startup using `pref()`, which
matches user.js's reset-on-startup behavior without locking preferences. This
applies to every Firefox profile, including newly created profiles. Firefox
owns profile creation and selection; the module writes no `profiles.ini`,
selects no profile path, and installs no launcher or desktop-entry override.
User-owned profile files remain Firefox's responsibility.

The module also generates native `distribution/policies.json`: `Extensions`
installs the configured add-ons from Mozilla's latest-version URLs, and
`SearchEngines.Add` adds the configured custom engines. Firefox manages add-on
updates and its own search database. Search-engine policies work on the regular
release channel starting with Firefox 139; no ESR-only policy bypass is needed.
Built-in engines and default selection stay with Firefox. Inspect `about:policies`
for policy errors and `about:config` for effective preferences.

The 2026-10-01 VM record reproduced why the old generated profile was ignored:
legacy `Default=1` did not set the installation's default profile. That launcher
fix has now been replaced by configuration that follows Firefox's selected
profile. Existing profile data is retained by shared-home reconciliation;
Firefox's own profile manager remains available if an account needs to select
its earlier profile. Existing user-owned profile configuration is retained.

Package availability sources: [AUR recipe](https://github.com/archlinux/aur/blob/arkenfox-user.js/PKGBUILD),
[Arch catalog](https://archlinux.org/packages/?q=arkenfox),
[Fedora catalog](https://packages.fedoraproject.org/search?query=arkenfox),
[COPR search](https://copr.fedorainfracloud.org/coprs/fulltext/?fulltext=arkenfox),
and [Terra recipes](https://github.com/terrapkg/packages/tree/frawhide).
Policy references: [Extensions](https://firefox-admin-docs.mozilla.org/reference/policies/extensions/),
[SearchEngines](https://firefox-admin-docs.mozilla.org/reference/policies/searchengines/).

Runtime provenance checked on 2026-10-01: [Arch Hyprland](https://archlinux.org/packages/extra/x86_64/hyprland/),
[Arch QMLTermWidget](https://archlinux.org/packages/extra/x86_64/qmltermwidget/),
[Fedora 44 QMLTermWidget](https://packages.fedoraproject.org/pkgs/qmltermwidget/qmltermwidget/fedora-44.html),
and [Fedora ty](https://packages.fedoraproject.org/pkgs/ty/ty/).
Fedora's QMLTermWidget listing uses Qt 5, while Zephyrus's current Quickshell
terminal requires Qt 6. Recheck distro versions before extending support.
