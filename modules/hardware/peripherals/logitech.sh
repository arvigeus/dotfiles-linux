#!/usr/bin/env bash
## Logitech peripheral support
## https://github.com/PixlOne/logiops
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

# Logitech USB vendor ID. A disconnected/Bluetooth-only device deliberately
# does not opt the machine into this device-specific configuration.
usb_vendor_present 046d || exit 0

case "$DISTRO" in
	fedora)
		pkg_install logiops
		;;
	arch)
		install_logiops() (
			set -Eeuo pipefail
			local tag tmpdir archive stage
			tag=$(github_latest_tag PixlOne/logiops)
			tmpdir=$(mktemp -d)
			trap 'rm -rf -- "$tmpdir"' EXIT
			archive="$tmpdir/logiops.tar.gz"
			stage="$tmpdir/stage"
			github_download \
				"https://github.com/PixlOne/logiops/archive/refs/tags/${tag}.tar.gz" \
				"$archive"
			mkdir -p "$tmpdir/source" "$tmpdir/build" "$stage"
			tar -xzf "$archive" --strip-components=1 -C "$tmpdir/source"
			cmake -S "$tmpdir/source" -B "$tmpdir/build" \
				-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
			cmake --build "$tmpdir/build" --parallel 1
			DESTDIR="$stage" cmake --install "$tmpdir/build"
			cp -a --no-preserve=ownership -- "$stage/." /
		)
		pkg_from_source install_logiops \
			cmake gcc make pkgconf libconfig libevdev systemd
		;;
esac

file_write /etc/logid.cfg <<'EOF'
devices: (
{
    name: "Wireless Mouse MX Master 3";
    smartshift: { on: true; threshold: 20; };
    hiresscroll: { hires: true; invert: false; target: false; };
    dpi: 2000;
    buttons: (
        {
            cid: 0xc3;
            action = {
                type: "Gestures";
                gestures: (
                    { direction: "None"; mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTMETA", "KEY_W"]; }; },
                    { direction: "Up"; mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_LEFTMETA", "KEY_UP"]; }; },
                    { direction: "Down"; mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_LEFTMETA", "KEY_DOWN"]; }; }
                );
            };
        }
    );
}
);
EOF
systemctl enable logid.service
