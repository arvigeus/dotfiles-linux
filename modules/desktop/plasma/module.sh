#!/usr/bin/env bash
## KDE Plasma desktop, integration, and behavior
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

requires=(system/security/ufw)

packages=(
	# Desktop and login manager
	plasma-desktop
	plasma-workspace
	plasma-nm
	plasma-pa
	bluedevil
	powerdevil
	kscreen
	dolphin
	konsole
	xdg-desktop-portal-kde
	arch:systemsettings
	fedora:plasma-systemsettings
	plasma-login-manager
	fedora:kcm-plasmalogin

    plasma-bigscreen

	# Plasma and Flatpak integration
	plasma-browser-integration
	flatpak-kcm

	# Dolphin protocols, privileged access, previews, and VCS integration
	kio-extras
	kio-fuse
	kio-admin
	ffmpegthumbs
	kdegraphics-thumbnailers
	dolphin-plugins
	arch:kimageformats
	fedora:kf6-kimageformats

	# Plasma applications
	arch:kdeconnect
	fedora:kde-connect
	arch:partitionmanager
	fedora:kde-partitionmanager

	arch:aur/crudini
	fedora:crudini

	flathub/de.swsnr.pictureoftheday

	arch:pkgbuild/plasma6-applets-overview-widget
	fedora:rpmspec/plasma6-applets-overview-widget
	arch:aur/plasma6-applets-wallhaven-reborn-git
	fedora:rpmspec/plasma6-applets-wallhaven-reborn
)

module_apply() {

	kde_default() {
		local file=${1:?file required}
		local group=${2:?group required}
		local key=${3:?key required}
		local value=${4-}
		install -d -m 0755 "$HOME/.config"
		crudini --set "$HOME/.config/$file" "$group" "$key" "$value"
	}

	# General desktop and Dolphin behavior.
	kde_default kdeglobals General accentColorFromWallpaper true
	kde_default kdeglobals KDE SingleClick true
	kde_default dolphinrc General BrowseThroughArchives true
	kde_default ksmserverrc General loginMode emptySession
	kde_default kwinrc Effect-overview BorderActivate 9 # Disable Overview effect on screen border
	kde_default ksplashrc KSplash Engine none

	# Auto login
	crudini --set /etc/plasmalogin.conf Autologin User "$USERNAME"
	crudini --set /etc/plasmalogin.conf Autologin Session plasma.desktop
	crudini --set /etc/plasmalogin.conf Autologin Relogin false

	# Configure screen locker
	kde_default kscreenlockerrc Daemon Autolock false
	kde_default kscreenlockerrc Daemon Timeout 0
	# kwriteconfig6 --file "kscreenlockerrc" --group "Greeter" --key "WallpaperPlugin" "com.plasma.wallpaper.wallhaven"
	# kwriteconfig6 --file "kscreenlockerrc" --group "Greeter" --group "Wallpaper" --group "com.plasma.wallpaper.wallhaven" --group "General" --key "WallpaperDelay" "1800"

	# US and Bulgarian phonetic layouts, switched per window with Alt+Shift.
	kde_default kxkbrc Layout DisplayNames ,
	kde_default kxkbrc Layout LayoutList us,bg
	kde_default kxkbrc Layout Options terminate:ctrl_alt_bksp,grp:alt_shift_toggle
	kde_default kxkbrc Layout ResetOldOptions true
	kde_default kxkbrc Layout SwitchMode Window
	kde_default kxkbrc Layout Use true
	kde_default kxkbrc Layout VariantList ,phonetic

	# Passwordless graphical login cannot pass a password to an encrypted wallet.
	# Disable KWallet instead of adding another prompt or an experimental backend.
	kde_default kwalletrc Wallet Enabled false
	kde_default kwalletrc Wallet 'First Use' false

	# Automatically switch between Breeze and Breeze Dark.
	kde_default kdeglobals KDE AutomaticLookAndFeel true
	kde_default kdeglobals KDE DefaultLightLookAndFeel org.kde.breeze.desktop
	kde_default kdeglobals KDE DefaultDarkLookAndFeel org.kde.breezedark.desktop

	for config in \
		kdeglobals dolphinrc ksmserverrc kwinrc ksplashrc kxkbrc kwalletrc; do
		home_strategy ".config/$config" ini unchanged
	done

	# Plasma Login Manager passwordless login.
	# getent group nopasswdlogin >/dev/null || groupadd --system nopasswdlogin
	# usermod --append --groups nopasswdlogin "$USERNAME"
	# if [[ ! -f /etc/pam.d/plasmalogin && -f /usr/lib/pam.d/plasmalogin ]]; then
	# 	install -Dm644 /usr/lib/pam.d/plasmalogin /etc/pam.d/plasmalogin
	# fi
	# [[ -f /etc/pam.d/plasmalogin ]] || {
	# 	printf 'Plasma Login Manager PAM policy was not installed\n' >&2
	# 	exit 1
	# }
	# if ! grep -Fq 'pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/plasmalogin; then
	# 	awk '
	# 	!added && $1 == "auth" {
	# 		print "auth       sufficient   pam_succeed_if.so user ingroup nopasswdlogin"
	# 		added = 1
	# 	}
	# 	{ print }
	# 	END {
	# 		if (!added)
	# 			print "auth       sufficient   pam_succeed_if.so user ingroup nopasswdlogin"
	# 	}' /etc/pam.d/plasmalogin | file_write /etc/pam.d/plasmalogin
	# fi

	systemctl enable plasmalogin.service
}

module_entrypoint "$@"
