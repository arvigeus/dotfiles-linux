# KDE Connect

Included by `communication` for both Plasma and Hyprland; selectable independently as
`communication/kdeconnect`. The upstream package owns XDG autostart and D-Bus activation
on both desktops. CLI operations are available through `kdeconnect-cli`.

The module owns its UFW rules: TCP/UDP 1714–1764 from private and link-local
IPv4/IPv6 sources. Internet-wide incoming access is not required. VPN consumers must preserve local routing for those networks and discovery traffic.
Globally routable LANs need explicit site-specific rules/exclusions.

Pair with the phone on the same LAN, then test discovery and a file transfer
with WARP on and off. Phone VPNs and access-point client isolation can still
prevent discovery. See [KDE's troubleshooting guide](https://userbase.kde.org/KDEConnect#Troubleshooting).
