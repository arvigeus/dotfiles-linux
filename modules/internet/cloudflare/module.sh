#!/usr/bin/env bash
## Cloudflare WARP prerequisite; registration and runtime control belong to consumers.
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"

packages=(arch:aur/cloudflare-warp-nox-bin fedora:cloudflare/cloudflare-warp)

module_apply() {
	# Provisioning installs the client without activating a tunnel at boot.
	systemctl disable warp-svc.service
	preserve_path /var/lib/cloudflare-warp

	# The official Fedora package also carries desktop/autostart launchers.
	local launcher
	while IFS= read -r -d '' launcher; do
		if grep -Eqi '^Exec=.*(warp-taskbar|warp-desktop|Cloudflare.?WARP)' "$launcher"; then
			sed -i '/^Hidden=/d; /\[Desktop Entry\]/a Hidden=true' "$launcher"
		fi
	done < <(find /etc/xdg/autostart /usr/share/applications -maxdepth 1 \
		-type f -name '*.desktop' -print0 2>/dev/null)
}

module_entrypoint "$@"
