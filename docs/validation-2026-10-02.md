# Browser configuration and recipe refresh — 2026-10-02

## Findings and changes

The preceding VM record established that the local Arkenfox package installed
successfully, but Firefox created a different per-install default profile and
ignored the generated user.js. The forced-profile launcher and rewritten
desktop entry have now been removed. `modules/browsers/firefox.sh` generates
Mozilla AutoConfig and extension/search policies in the native installation;
Firefox creates and selects profiles and manages its own search database.
Arkenfox preferences and the existing local overrides apply at browser startup
without preference locks. Extension downloads use Mozilla's latest-version
URLs rather than fixed file IDs.

Arch's official package search returned zero Arkenfox matches. Stable
`arkenfox-user.js` is available in AUR; its recipe installs the template at
`/usr/share/arkenfox-user.js/user.js`. Chaotic's current database carries only
the development `arkenfox-user.js-git` package, so stable AUR is preferred.
Fedora's official package catalog and COPR project search returned no matches;
Terra's complete frawhide tree also had no match. Fedora retains its automatic
stable-release RPM fallback, now using the same template path as AUR.
See [Firefox configuration](desktops.md#firefox-configuration) for source links.

The shared installer already called recipe refresh before package installation
from both bootstrap and rebuild. Added tests exercise that actual orchestration
on Arch and Fedora with mounts/chroot/package installation stubbed, confirm that
tracked snapshots stay untouched, and confirm that updater failures stop before
package installation or module application. Draft/prerelease responses and
responses missing those flags are rejected explicitly.

sosc and Fedora's Wallhaven updater previously followed HEAD despite stable
releases being available. They now resolve stable release tags to commits.
Thumbfast and Overview publish neither releases nor version tags; their
existing snapshot paths remain documented exceptions. Zephyrus retains its
explicit VCS build. These exceptions cannot be called stable upstream releases.

## Validation performed

- `bash tests/run.sh`: passed, including both distribution package-plan paths,
  missing-template checks, native policy generation, recipe refresh ordering,
  failed-updater abort, and static contracts.
- Targeted ShellCheck passed with exclusions for the repository's sourced module
  globals and test callbacks. `git diff --check` passed.
- Real Firefox 157.0 was copied to `/tmp/dotfiles-firefox-runtime`, with a temporary
  HOME created and deleted by the test. The host installation/profile were not
  changed. The sandboxed browser crashed; the disposable browser check passed
  outside that sandbox, retaining Firefox's normal browser sandbox settings.
- `FIREFOX_TEST_INSTALL_DIR=/tmp/dotfiles-firefox-runtime
  ARKENFOX_TEST_TEMPLATE=/tmp/dotfiles-arkenfox-stable.js bash tests/firefox.sh`
  loaded the actual stable Arkenfox 144.0 template. A normal launch without
  `--profile` created its own profile and saved Arkenfox's
  `network.http.referer.XOriginTrimmingPolicy=2`, local
  `signon.rememberSignons=false`, and `browser.startup.page=3` in prefs.js.
  A second launch with a native alternate profile also loaded the preferences
  without a profile user.js. Both headless screenshots were generated.
- Live updater runs against temporary copies resolved Arkenfox 144.0, sosc
  1.0.1 at `78d79159bac4821d06e116e692a61ad30bfb6f05`, Wallhaven 2.1.0 at
  `7e3b812e04facffef38fa52723c39c27284a97dc`, and system-mpv-extras
  `3.0.0.20260308.1.0.1`. Source downloads and checksum generation succeeded;
  the sosc/Wallhaven stable archives still contain the package recipes' required
  paths. Tracked recipe snapshots were not updated by these checks.

No package installation, Fedora browser runtime, full booted-VM regression, or
physical GA402RK validation was performed for this change. The browser runtime
test disables extension downloads in its disposable policy copy, so real add-on
installation and GUI search-engine presentation still need booted guest checks.
`vm/verify.sh` now uses the distribution binary and inspects Firefox's native
per-install profile selection rather than a fixed profile path.
