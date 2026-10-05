# Cloudflare WARP prerequisite

`internet/cloudflare` installs Arch's CLI-only `cloudflare-warp-nox-bin` or
Fedora's signed official `cloudflare-warp` package. Fedora desktop/autostart
launchers are hidden. The daemon is disabled at boot and existing registration
state in `/var/lib/cloudflare-warp` is preserved across rebuilds.

This module never registers, connects, configures split tunnels, or installs
runtime control helpers. Consumers such as zephyrus-shell own those operations
and their authorization. Package installation does not accept Cloudflare's terms.

Sources: [Linux setup](https://developers.cloudflare.com/warp-client/get-started/linux/),
[official RPM repository](https://pkg.cloudflareclient.com/).
