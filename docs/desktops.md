# Desktop profiles and Python development

`HOST_PROFILE` selects `hosts/<profile>.sh`, independently of the machine's
`HOSTNAME`. `DESKTOP` is `plasma` or `hyprland`; both are saved with the other
non-secret settings in `/etc/system/config`. Older configurations without these
keys use their existing hostname as the profile and default to Plasma.

The installer passes desktop/profile values to every module's plan, apply and
healthcheck process, including preflight. `desktop/module.sh` selects the
chosen implementation alongside shared Electron defaults and fonts. The
`hardware/keyboard/input-method` module owns
[keyboard languages and on-demand Vietnamese input](../modules/hardware/keyboard/input-method/README.md). A plan
records each package's declaring leaf in `/var/log/system/package-plan.tsv`,
so its owner is directly visible.

| Selection | Desktop owner | Login owner | Desktop-specific media |
| --- | --- | --- | --- |
| Plasma | `desktop/plasma` | Plasma Login Manager, existing autologin policy | common media module includes Kodi |
| Hyprland | `desktop/hyprland` | greetd, once-per-boot autologin; tuigreet after logout | Kodi skips Hyprland |

Hyprland automatically logs in the configured `USERNAME` through UWSM at boot.
Logging out returns to tuigreet, where another installed Wayland session can be
selected and authenticated. The module writes greetd's `initial_session` for
autologin and keeps its session chooser as `default_session`. greetd's runfile
prevents autologin from repeating after logout or a greetd restart until the next
boot; see the [greetd configuration manual](https://man.archlinux.org/man/greetd.5.en).

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

The `desktop/hyprland` leaf requests
`arch:git-pkgbuild/github.com/arvigeus/zephyrus-shell`. Its module-local provider
is generic: it fetches a Git repository containing a root PKGBUILD and installs
all its split outputs with the existing unprivileged makepkg/pacman builder.
The shell repository owns dependency metadata, system payloads, installation
paths, session entry points and appearance defaults. Dotfiles retains selected
companion applications/MIME defaults, greetd policy and machine DDC permissions.
The provider stays module-local because this is currently its only consumer;
move it to shared sources if another leaf needs it.

The leaf explicitly enables official Arch multilib before package installation.
Zephyrus's upstream optional dependencies include Legendary and umu; umu needs
32-bit libraries even when the selected host has no Steam or physical GPU
module. Multilib precedes Chaotic-AUR/OGC so dependency resolution prefers the
official libraries. ALHP also enables this fallback before its first upgrade.

Every bootstrap/rebuild clones current public default-branch HEAD. Standard Git
URL rewriting makes makepkg use that same checkout for matching VCS sources,
avoiding another fetch and metadata/payload revision races. Generated SRCINFO is
retained under `/var/lib/system/git-pkgbuild` for native installed-state/removal
queries; no copied metadata or recipe is tracked here. Existing local recipes
still run through `packages/update.sh`; Zephyrus no longer has such a recipe or
a recipe updater. Rebuild's normal source-install phase refreshes it each time.
The active-root updater's pacman transaction updates repository packages only;
it does not update this external VCS recipe. Use rebuild, or the upstream local
build/install command when updating the mutable running root.

After installation the module calls the public `zephyrus-shell-session provision`
command in the candidate skeleton. Zephyrus emits the reconciliation inventory,
so dotfiles does not enumerate session files. Generated session configuration
survives a switch to the fallback desktop; appearance defaults preserve personal
edits. Healthchecks call `zephyrus-shell-session check` and verify greetd policy.
Audio/network/Bluetooth modules deliberately own service activation and retained
machine state. DDC module loading on future boots and I2C membership remain an
explicit machine policy here. The packaged hardware helper is available for
standalone setup, but is not run against the active kernel from a candidate.
No new power-profile authority is selected.

For source development use the upstream `scripts/build-package.sh`, which
includes non-ignored working-tree changes without modifying Git history.
For a direct provider test on the running root, set `GIT_PKGBUILD_LOCAL_DIR` to
an explicit local checkout and invoke the provider through the normal source
contract. See [source workflow](../sources/README.md). Rebuild forwards this
variable, but the path must already exist **inside the candidate namespace**;
it deliberately does not bind-mount or discover the developer's home. Ordinary
production rebuilds leave it unset and use remote sources. Publish the upstream
packaging changes before a fresh remote rebuild.

Private provider configuration remains outside packages. Companion application
choices are described in [Hyprland desktop kit](hyprland-desktop-kit.md).
Session startup still needs a live login test; see [VM validation](vm-validation.md).

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
