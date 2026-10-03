#!/usr/bin/env bash
# Run inside the booted guest after logging into the selected desktop.
set -Eeuo pipefail
[[ -r /etc/system/config ]] || {
	printf 'Installed config missing\n' >&2
	exit 1
}
source /etc/system/config
user_id=$(id -u "$USERNAME")
printf 'Persisted profile=%s desktop=%s hostname=%s\n' "$HOST_PROFILE" "$DESKTOP" "$HOSTNAME"
for command in python3 uv ruff ty firefox; do
	command -v "$command" >/dev/null || {
		printf 'Missing command: %s\n' "$command" >&2
		exit 1
	}
done
python3 --version
python3 -m pip --version
uv --version
ruff --version
ty --version
[[ -s /usr/share/arkenfox-user.js/user.js ]]
firefox_dir=/usr/lib/firefox
[[ ! -x /usr/lib64/firefox/firefox ]] || firefox_dir=/usr/lib64/firefox
[[ -s $firefox_dir/arkenfox.cfg && -s $firefox_dir/defaults/pref/arkenfox.js ]]
jq -e '.policies.Extensions.Install | length > 0' "$firefox_dir/distribution/policies.json" >/dev/null
# Run Firefox normally (no --profile) as the installed user, then check the
# preferences it actually loaded. Close any interactive Firefox first.
if pgrep -u "$USERNAME" -x firefox >/dev/null; then
	printf 'Close Firefox before running VM verification.\n' >&2
	exit 1
fi
browser_test=$(mktemp -d)
trap 'rm -rf -- "$browser_test"' EXIT
if ((EUID == 0)); then
	chown "$USERNAME" "$browser_test"
	timeout 90 runuser -u "$USERNAME" -- env HOME="/home/$USERNAME" \
		XDG_CONFIG_HOME="/home/$USERNAME/.config" XDG_RUNTIME_DIR="/run/user/$user_id" /usr/bin/firefox \
		--headless --screenshot "$browser_test/firefox.png" about:blank
else
	[[ $(id -un) == "$USERNAME" ]]
	timeout 90 /usr/bin/firefox --headless --screenshot "$browser_test/firefox.png" about:blank
fi
# Inspect Firefox's per-install selection instead of assuming a profile name.
preferences=$(python3 - "/home/$USERNAME" "$firefox_dir" <<'PY'
import configparser
from pathlib import Path
import sys

home, install = map(Path, sys.argv[1:])
selected = set()
for root in (home / '.mozilla/firefox', home / '.config/mozilla/firefox'):
    profiles = configparser.ConfigParser(interpolation=None)
    profiles.read(root / 'profiles.ini')
    for section in profiles.sections():
        if not section.startswith('Install'):
            continue
        profile = root / profiles.get(section, 'Default', fallback='')
        compatibility = configparser.ConfigParser(interpolation=None)
        compatibility.read(profile / 'compatibility.ini')
        app_dir = compatibility.get('Compatibility', 'LastAppDir', fallback='')
        if app_dir and Path(app_dir).resolve() == install.resolve():
            selected.add((profile / 'prefs.js').resolve())
if len(selected) != 1:
    raise SystemExit('Cannot identify Firefox default profile; inspect about:profiles.')
print(selected.pop())
PY
)
grep -Fq 'user_pref("network.http.referer.XOriginTrimmingPolicy", 2);' "$preferences"
grep -Fq 'user_pref("signon.rememberSignons", false);' "$preferences"
grep -Fq 'user_pref("browser.startup.page", 3);' "$preferences"
[[ -s $browser_test/firefox.png ]]
case $DESKTOP in
hyprland)
	[[ ! -e /usr/bin/plasmashell && ! -e /etc/plasmalogin.conf ]]
	if command -v flatpak >/dev/null && flatpak info --system tv.kodi.Kodi >/dev/null 2>&1; then
		printf 'Kodi unexpectedly installed in Hyprland guest\n' >&2
		exit 1
	fi
	[[ -s /usr/share/zephyrus-shell/REVISION ]]
	grep -Fq /usr/share/zephyrus-shell /home/"$USERNAME"/.config/hypr/hyprland.lua
	pgrep -u "$USERNAME" -x Hyprland >/dev/null
	pgrep -u "$USERNAME" -f '^quickshell -n -p /usr/share/zephyrus-shell$' >/dev/null
	printf 'Zephyrus revision: %s\n' "$(cat /usr/share/zephyrus-shell/REVISION)"
	;;
plasma)
	[[ ! -e /usr/share/zephyrus-shell && ! -e /etc/greetd/config.toml ]]
	flatpak info --system tv.kodi.Kodi >/dev/null
	pgrep -u "$USERNAME" -x plasmashell >/dev/null
	;;
*)
	printf 'Unknown desktop: %s\n' "$DESKTOP" >&2
	exit 1
	;;
esac
printf 'Booted desktop, Python and loaded Arkenfox preferences: ok\n'
