#!/usr/bin/env bash
## KDE Plasma desktop, integration, and behavior
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

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

	# Plasma rc files are staged as INI fragments and merged into persistent home.
	arch:aur/crudini
	fedora:crudini

	# Wallpaper utility retained from the previous setup.
	flathub/de.swsnr.pictureoftheday

	# Overview has no distro package; Wallhaven is already packaged on Arch.
	arch:pkgbuild/plasma6-applets-overview-widget
	fedora:rpmspec/plasma6-applets-overview-widget
	arch:aur/plasma6-applets-wallhaven-reborn-git
	fedora:rpmspec/plasma6-applets-wallhaven-reborn
)

pkg_install "${packages[@]}"

kde_default() {
	local file=${1:?file required}
	local group=${2:?group required}
	local key=${3:?key required}
	local value=${4-}
	install -d -m 0755 "$HOME/.config"
	crudini --set "$HOME/.config/$file" "$group" "$key" "$value"
}

# General desktop and Dolphin behavior.
kde_default kdeglobals KDE SingleClick true
kde_default dolphinrc General BrowseThroughArchives true
kde_default ksmserverrc General loginMode emptySession
kde_default kwinrc Effect-overview BorderActivate 9
kde_default ksplashrc KSplash Engine none

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

for config in \
	kdeglobals dolphinrc ksmserverrc kwinrc ksplashrc kxkbrc kwalletrc; do
	home_strategy ".config/$config" ini unchanged
done

# Plasma Login Manager passwordless login. The lock screen keeps its separate
# /etc/pam.d/kde policy and therefore still requires the account password.
getent group nopasswdlogin >/dev/null || groupadd --system nopasswdlogin
usermod --append --groups nopasswdlogin "$USERNAME"
if [[ ! -f /etc/pam.d/plasmalogin && -f /usr/lib/pam.d/plasmalogin ]]; then
	install -Dm644 /usr/lib/pam.d/plasmalogin /etc/pam.d/plasmalogin
fi
[[ -f /etc/pam.d/plasmalogin ]] || {
	printf 'Plasma Login Manager PAM policy was not installed\n' >&2
	exit 1
}
if ! grep -Fq 'pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/plasmalogin; then
	awk '
		!added && $1 == "auth" {
			print "auth       sufficient   pam_succeed_if.so user ingroup nopasswdlogin"
			added = 1
		}
		{ print }
		END {
			if (!added)
				print "auth       sufficient   pam_succeed_if.so user ingroup nopasswdlogin"
		}' /etc/pam.d/plasmalogin | file_write /etc/pam.d/plasmalogin
fi

# KDE Connect ships a UFW application profile. Add it once on the booted
# target, after UFW has loaded, rather than touching the build host firewall.
file_write -m 0755 /usr/local/libexec/system-enable-kdeconnect-firewall <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
marker=/var/lib/system/kdeconnect-ufw-configured
[[ -e $marker ]] && exit 0
install -d -m 0755 /var/lib/system
if ufw app info KDEConnect >/dev/null 2>&1; then
	ufw allow KDEConnect
else
	ufw allow 1714:1764/tcp
	ufw allow 1714:1764/udp
fi
touch "$marker"
EOF
file_write /etc/systemd/system/system-kdeconnect-firewall.service <<'EOF'
[Unit]
Description=Allow KDE Connect through UFW
After=ufw.service
Wants=ufw.service
ConditionPathExists=!/var/lib/system/kdeconnect-ufw-configured

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/system-enable-kdeconnect-firewall

[Install]
WantedBy=multi-user.target
EOF

systemctl enable plasmalogin.service system-kdeconnect-firewall.service
