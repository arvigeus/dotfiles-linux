# A complete Hyprland desktop

The Hyprland leaf includes the daily desktop tools even on a small host profile.
Quickshell owns the bar, launcher, notifications, settings and quick tools;
ordinary file associations open independent application windows. Existing Files,
Pictures and Terminal spaces continue to serve their current roles.

| Task | Desktop companion | Integration |
| --- | --- | --- |
| Files, Trash and removable drives | Dolphin | Super+E; directory defaults; UDisks mounts through its sidebar |
| Pictures and simple image edits | Gwenview | Image defaults; extra Qt/KDE formats, including HEIF/AVIF/JXL libraries |
| PDF and document reading | Okular | PDF and EPUB defaults |
| Archives | Ark | Archive defaults, Dolphin integration; base archive tools retained |
| Quick text edits | KWrite, provided by kate | Text and Markdown defaults; coding editors remain available |
| Terminal | Kitty | Super+Enter, TERMINAL default and Dolphin terminal integration |
| Video and audio files | mpv | Media defaults; common media modules still own their enhanced configuration |
| Web links | Firefox | Browser dependency and HTTP/HTTPS defaults; existing user choices take precedence |
| Screenshots and annotation | Hyprshot + Satty | Settings and Print open an area capture in the editor; quick capture shortcuts save and copy directly |
| Screen recording | Kooha | Settings and Super+Alt+R open native recording controls through the desktop portal |
| Clipboard | cliphist + wl-clipboard | Native Clipboard space, Settings action and Super+Shift+V |

The purpose of the companion set is to make opening a file predictable. The
Hyprland-only `/etc/xdg/hyprland-mimeapps.list` supplies system defaults without
replacing a user's `mimeapps.list` or changing Plasma's defaults. KIO extras and
KIO FUSE provide remote protocols and access for applications outside KIO.
Image, PDF and video thumbnail providers are installed alongside Dolphin.
User changes to the generated appearance and Dolphin settings survive rebuilds.

## One visual language

Zephyrus generates application colors and fonts from
`$XDG_CONFIG_HOME/zephyrus-shell/theme.json`. The shell watches that file and
updates KDE/Qt 5/Qt 6, GTK 3/GTK 4/libadwaita, Kitty, installed Zed/VS Code
settings, the dark/light portal preference and Hyprland borders. KDE's standalone
platform themes consume `kdeglobals` with Fusion widgets; no Plasma session runs.
The upstream full-session package supplies the Qt 5 and Qt 6 integration libraries. Application icons
use Breeze; shell controls keep bundled Lucide icons.

Installed Flatpaks receive per-app read access to the GTK appearance directories
and `kdeglobals`, preserving unrelated permissions and explicit denials. Host
fonts are already exposed by Flatpak. Sandboxed toolkit support and applications
with their own skins still vary. Some applications need reopening after a change.
The shell's `docs/theme.md` lists application coverage, limitations, font units,
configuration commands and reversible restoration.

The stable `hyprqt6engine` package remains available for users who explicitly
select it. Its generated config points at the same Zephyrus colors and fonts;
KDE integration is the default so Qt 5 applications share the palette too.
Platform variables are scoped to Hyprland and imported through UWSM. Appearance
files provisioned by the upstream package are bootstrap defaults; runtime generation owns subsequent
changes and home reconciliation preserves user edits.

## Capture and paste

- Print or Super+Shift+S selects an area and opens Satty. Enter saves the
  annotated image, copies it and closes the editor. Escape keeps the original capture.
- Super+Shift+Print captures an area directly.
- Super+Print captures the active window; Super+Ctrl+Print selects a window.
- Shift+Print captures the active output.
- Super+Alt+R opens Kooha; choose screen/area and audio in its native controls.
- Super+Shift+V opens searchable clipboard history. Enter or a click copies the
  selected entry and closes the module; paste normally in your app.
- Delete removes a selected clipboard entry. Clear history requires a second
  click within five seconds.

Screenshots preserve shell overlays during selection and use the user's localized
XDG Pictures directory. Hyprshot, Satty and Kooha are official Arch packages.
Capture scripts, Satty configuration and shortcuts belong to `zephyrus-shell`;
the upstream package declares their dependencies. Kooha retains its normal application settings
and uses the existing PipeWire/desktop-portal stack. The shortcut opens its
controls; starting and stopping a recording happens there. The clipboard session
has separate text and image
watchers owned by `graphical-session.target`, conditioned on Hyprland. History
is held in the user's XDG cache and capped at 200 entries. Module workers exist
only while their module is open. Copying preserves text or image bytes and MIME
identity; it does not synthesize keystrokes into the destination application.

## Coverage and deliberate boundaries

The full workstation profile additionally carries browsers, office creation,
communication, media editing and development tools. This kit makes the smaller
Hyprland profile usable for everyday files too. Printing/scanning, credential
storage deserve their own device/login or workflow setup;
no blanket print driver collection, second launcher, notification daemon,
automounter or desktop session is added here.

Validation: dotfiles package graph and static contracts; clean native package
builds; shell Python tests; real cliphist with isolated history and the real
module loader; actual Qt platform-theme palette and rendering. Capture helper
unit tests verify overlay dismissal, XDG paths, cancellation and output choice.
Physical USB/remote-share and printing behavior are not claimed tested.

Sources: [Hyprland Qt engine](https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/),
[Hyprshot](https://github.com/Gustash/Hyprshot),
[Satty](https://github.com/Satty-org/Satty), [Kooha](https://github.com/SeaDve/Kooha),
[cliphist](https://github.com/sentriz/cliphist),
[Gwenview](https://apps.kde.org/gwenview/), [Ark](https://apps.kde.org/ark/).
