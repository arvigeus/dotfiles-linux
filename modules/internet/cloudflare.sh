#!/usr/bin/env bash
## Cloudflare WARP client (disabled until explicitly enabled)
## https://developers.cloudflare.com/warp-client/get-started/linux/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

# WARP changes the host's network path and registration state. Keep the module
# visible in the graph but inactive until that policy is explicitly chosen.
module_check() {
	return 1
}

packages=(
	arch:aur/cloudflare-warp-bin
)

module_apply() {
	[[ $DISTRO == arch ]] || return 0

	file_write /etc/polkit-1/rules.d/90-warp-service.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.systemd1.manage-units" ||
         action.id == "org.freedesktop.systemd1.manage-unit-files") &&
        action.lookup("unit") == "warp-svc.service" &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

	# Provisioning has no running target systemd instance. Initialize the WARP
	# registration only after the installed system has booted and networking is up.
	file_write /etc/systemd/system/system-warp-initialize.service <<'EOF'
[Unit]
Description=Initialize Cloudflare WARP registration and local split tunnels
Wants=network-online.target
After=network-online.target warp-svc.service
Requires=warp-svc.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c '/usr/bin/warp-cli tunnel ip add-range 192.168.0.0/16 || true; /usr/bin/warp-cli tunnel ip add-range 172.16.0.0/12 || true; /usr/bin/warp-cli tunnel ip add-range 10.0.0.0/8 || true; /usr/bin/warp-cli registration show >/dev/null 2>&1 || /usr/bin/warp-cli registration new; /usr/bin/warp-cli connect'

[Install]
WantedBy=multi-user.target
EOF

	systemctl enable warp-svc.service system-warp-initialize.service
}

module_entrypoint "$@"
