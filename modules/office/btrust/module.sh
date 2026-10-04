#!/usr/bin/env bash
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/browsers.sh"

# sac-core supplies the signing libraries; sac-gui/SACMonitor are unnecessary.
packages=(
	arch:aur/btrustbiss arch:aur/sac-core
	arch:pcsclite arch:ccid arch:nss arch:chromium
	arch:opensc arch:pcsc-tools arch:python arch:ripgrep
)
requires=(browsers/firefox system/security/polkit)

module_check() {
	[[ $DISTRO == arch ]] && return 0
	printf 'B-Trust: Arch packaging only; skipping on %s. See office/btrust/README.md.\n' "$DISTRO" >&2
	return 1
}

module_apply() {
	[[ -x /opt/btrustbiss/bin/BISS && -r /usr/lib/pkcs11/libIDPrimePKCS11.so ]]
	# Undo the AUR install hook, also enforced after mutable package upgrades.
	/usr/local/libexec/system-btrust-maintain
	# User overrides cover login entries left over by the previous installation.
	for entry in btrustbiss-BISS SACMonitor; do
		printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "$entry" |
			file_write "$HOME/.config/autostart/$entry.desktop"
		home_strategy ".config/autostart/$entry.desktop" replace always
	done

	# Allow this installation's one desktop user to manage only the QES target.
	# Cleanup must still work after the user's session becomes inactive on logout.
	cat <<EOF | file_write /etc/polkit-1/rules.d/50-system-btrust.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "system-btrust.target" &&
        subject.user == "$USERNAME") {
        var verb = action.lookup("verb");
        if (verb == "stop" || verb == "start")
            return polkit.Result.YES;
    }
});
EOF
	local firefox_dir=/usr/lib/firefox
	[[ ! -x /usr/lib64/firefox/firefox ]] || firefox_dir=/usr/lib64/firefox
	local policies
	policies=$(firefox_merge_feature_policies <"$firefox_dir/distribution/policies.json")
	printf '%s\n' "$policies" | file_write "$firefox_dir/distribution/policies.json"

	# NSS lives in the real user's persistent home and is initialized on launch.
	# Shipping database files in skel would overwrite browser state on rebuilds.
	preserve_path /etc/udev/rules.d/71-system-btrust.rules
}

module_healthcheck() {
	[[ -x /opt/btrustbiss/bin/BISS && -r /usr/lib/pkcs11/libIDPrimePKCS11.so ]]
	if systemctl is-enabled --quiet pcscd.socket || systemctl is-enabled --quiet pcscd.service; then
		printf 'B-Trust PC/SC units must not be enabled at boot.\n' >&2
		return 1
	fi
	jq -e '.policies.SecurityDevices.Add["B-Trust IDPrime"] == "/usr/lib/pkcs11/libIDPrimePKCS11.so"' \
		/usr/lib/firefox/distribution/policies.json >/dev/null
}

module_entrypoint "$@"
