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
	systemctl enable greetd.service
}

module_healthcheck() {
	zephyrus-shell-session check
	command -v tuigreet >/dev/null
	systemctl is-enabled --quiet greetd.service
	[[ -s /etc/xdg/hyprland-mimeapps.list ]]
}

module_entrypoint "$@"
