#!/usr/bin/env bash
## Zephyrus on Hyprland; system policy belongs here, never in setup-system.sh.
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"

[[ $DISTRO == arch ]] || {
	printf 'Zephyrus Hyprland currently supports Arch only; choose Plasma on Fedora.\n' >&2
	exit 1
}

# UWSM and standard systemd user services own the graphical-session lifecycle.
requires=(hardware/audio hardware/network hardware/bluetooth base/archive base/xdg browsers/firefox)
# Upstream's Epic runner needs 32-bit dependencies even on the minimal VM
# profile, which does not select gaming/steam or a physical GPU module.
sources=(arch:multilib)
packages=(
	arch:git-pkgbuild/github.com/arvigeus/zephyrus-shell
	# Machine-selected desktop companions and MIME defaults.
	koko okular ark kate
	kio-extras kio-fuse ffmpegthumbs kdegraphics-thumbnailers kimageformats qt6-imageformats libheif libavif libjxl
	udisks2
	greetd greetd-tuigreet
)

module_apply() {
	# The package owns its payload and emits its reconciliation inventory.
	mkdir -p "/etc/$PROJECT_ID"
	zephyrus-shell-session provision --home-strategies "/etc/$PROJECT_ID/home-strategies.tsv"
	# The installed shell owns WARP policy and its authorization.
	zephyrus-shell-warp setup --user "$USERNAME" --offline

	printf 'i2c-dev\n' | file_write /etc/modules-load.d/ddc.conf
	getent group i2c >/dev/null || groupadd --system i2c
	usermod --append --groups i2c "$USERNAME"
	getent passwd greeter >/dev/null || useradd --system --no-create-home --shell /usr/bin/nologin greeter
	# greetd runs initial_session once per boot; logout returns to tuigreet.
	# The file overlay resets the greeter configuration before each apply.
	file_append /etc/greetd/config.toml <<EOF

[initial_session]
command = "uwsm start -e -D Hyprland hyprland.desktop"
user = "$USERNAME"
EOF
	systemctl enable greetd.service
}

module_healthcheck() {
	zephyrus-shell-session check
	command -v tuigreet >/dev/null
	systemctl is-enabled --quiet greetd.service
	grep -Fxq '[initial_session]' /etc/greetd/config.toml
	grep -Fxq 'command = "uwsm start -e -D Hyprland hyprland.desktop"' /etc/greetd/config.toml
	grep -Fxq "user = \"$USERNAME\"" /etc/greetd/config.toml
	[[ -s /etc/xdg/hyprland-mimeapps.list ]]
}

module_entrypoint "$@"
