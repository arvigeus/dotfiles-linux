#!/usr/bin/env bash
## Logitech peripheral support
## https://github.com/PixlOne/logiops
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/hardware.sh"

# Logitech USB vendor ID. A disconnected/Bluetooth-only device deliberately
# does not opt the machine into this device-specific configuration.
usb_vendor_present 046d || exit 0

packages=(
    arch:chaotic-aur/logiops
    fedora:logiops
)
pkg_install "${packages[@]}"

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
