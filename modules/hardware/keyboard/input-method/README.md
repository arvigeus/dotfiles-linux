# Explicit Vietnamese input

`hardware` includes `hardware/keyboard/input-method` on both supported desktops.
Its `bg` leaf configures English/Bulgarian phonetic; its `vn` leaf installs and
configures Vietnamese UniKey/Telex without starting Fcitx. Selecting `bg` alone
installs no Vietnamese packages. A shared `common` leaf supplies the Bash
controller and tools (`jq`, `flock`, `gdbus`, `awk`, `timeout`), with no Python
runtime dependency. Changes are applied by the normal rebuild and next boot.

## Hyprland / Zephyrus

The right-hand button shows the active input language. English uses a neutral
globe; Bulgarian and Vietnamese use flags. The dropdown has language labels:

- 🇧🇬 selects Bulgarian phonetic and stops Vietnamese input. Alt+Shift switches
  between English and Bulgarian.
- 🇻🇳 starts Fcitx and selects Vietnamese Telex. Alt+Shift switches between
  English and Vietnamese; Bulgarian is outside this pair.
- **English** selects English while keeping the chosen secondary language.

The selected pair is global, and the active XKB layout is maintained per
keyboard across all applications; there is no per-window layout memory in
Hyprland. Vietnamese input state is shared globally too. The pair survives
compositor and shell reloads. A new login starts with
English/Bulgarian, with Fcitx stopped. Vietnamese remains running when English
is selected within the English/Vietnamese pair, so Alt+Shift can return to it.
Select Bulgarian to stop it completely.

Zephyrus exposes a generic input-provider interface. This module supplies
`~/.config/zephyrus-shell/input-language.json` with
`{"command":["/usr/local/bin/system-input-method"]}`. The shell only knows its
public command/JSON contract, not this repository, its module paths, controller
name or user unit. Vietnamese stays hidden if the configured provider reports
missing prerequisites. The Bash controller owns package checks, configuration,
service startup and private session state.

The `bg` module also supplies the shell's optional user keyboard defaults.
The controller publishes compositor layout changes through the shell's public
`$XDG_RUNTIME_DIR/zephyrus-shell/input-language-INSTANCE.lua` override, preserving
the selected pair during reloads without exposing private controller paths.
Only this repository consumes Zephyrus's interfaces; the shell has no dependency
on this repository. Installed Zephyrus packages need rebuilding with its new
language button and provider interface too.

A checkout config edit needs a compositor reload, not a logout. For a narrow
keyboard-only reload in a running Hyprland session, load its input module:

```sh
hyprctl eval 'dofile("/home/arvigeus/Projects/zephyrus-shell/hyprland/input-method.lua")'
```

The controller, Fcitx packages, on-demand unit and environment routing still
need the module installed through the normal rebuild. Once installed, clicking
Vietnamese handles startup; no preliminary service launch is needed.

## Plasma Wayland

Launch **Vietnamese Telex** from the application menu. KWin starts Fcitx through
its virtual-keyboard integration; the launcher configures the English/UniKey
profile and Telex automatically. Ctrl+Space switches English/Vietnamese while
it is running. Alt+Shift remains the normal English/Bulgarian phonetic shortcut, with the
layout remembered per window (`SwitchMode=Window`).
Launch **Stop Vietnamese input** (also a desktop action on the start entry) to
stop it. A new login requires explicitly starting Vietnamese again.

The KWin launcher is gated by runtime state belonging to that KWin D-Bus owner.
An old selection cannot enable Fcitx in a new session, including when systemd
user processes linger. Fcitx is prevented from overwriting Plasma's layout list.

## Implementation and checks

There is one controller, `/usr/local/bin/system-input-method`. Hyprland uses a
manually started systemd user unit without an `[Install]` section. Plasma uses
KWin as its process owner. Package XDG autostart and toolkit D-Bus activation
are overridden for this user; environment routing alone does not start Fcitx.
Native GTK Wayland and Plasma Qt applications use compositor input protocols.
Hyprland sets `QT_IM_MODULE=fcitx` for Qt 5 support; XWayland uses
`XMODIFIERS=@im=fcitx`. Some legacy or sandboxed applications may need their
input-method plugin or a relaunch; the controller cannot change the environment
of an already running application.

`python3 tests/input-method.py` exercises the real controller with simulated
compositor/service tools, including failed-start rollback and generated Arch
and Fedora Plasma configuration. Zephyrus's `scripts/check-language.sh` tests
its real QML menu using an isolated controller fixture. These checks do not
validate physical typing, modifier handling, focus grabs or client compatibility
in either running desktop; test those after booting the rebuilt configuration.

Upstream behavior used here:
[Fcitx Wayland integration](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland),
[KWin's input-method config watcher](https://github.com/KDE/kwin/blob/master/src/main_wayland.cpp),
[Fcitx's compositor layout override](https://github.com/fcitx/fcitx5/blob/master/src/modules/wayland/waylandmodule.h),
[UniKey options](https://github.com/fcitx/fcitx5-unikey/blob/master/src/unikey-config.h).
