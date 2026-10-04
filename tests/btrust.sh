#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
module=$PROJECT_ROOT/modules/office/btrust
files=$module/files

for distro in arch fedora; do
	manager=pacman
	[[ $distro != fedora ]] || manager=dnf
	env SETUP_ROOT="$PROJECT_ROOT" PROJECT_ID=system DISTRO="$distro" PACKAGE_MANAGER="$manager" \
		MODULE_ID=office/btrust MODULE_DIR="$module" MODULE_PHASE=plan MODULE_PLAN_FILE="$TEST_ROOT/$distro.plan" \
		bash "$module/module.sh"
done
rg -q '^package[[:space:]]+arch:aur/sac-core$' "$TEST_ROOT/arch.plan"
rg -q '^require[[:space:]]+browsers/firefox$' "$TEST_ROOT/arch.plan"
if rg -q 'sac-gui|google.Chrome|google-chrome' "$TEST_ROOT/arch.plan"; then
	printf 'B-Trust selected an excluded GUI or Chrome package.\n' >&2
	exit 1
fi
rg -q '^skip' "$TEST_ROOT/fedora.plan"

export SETUP_ROOT=$PROJECT_ROOT PROJECT_ID=system
source "$PROJECT_ROOT/lib/browsers.sh"
export FIREFOX_FEATURE_POLICIES_DIR=$files/etc/system/firefox-policies.d
printf '{"policies":{"Extensions":{"Install":["existing"]},"SearchEngines":{"Add":[]}}}' |
	firefox_merge_feature_policies >"$TEST_ROOT/policies.json"
jq -e '.policies | .Extensions.Install == ["existing"] and
	.SecurityDevices.Add["B-Trust IDPrime"] == "/usr/lib/pkcs11/libIDPrimePKCS11.so" and
	.LocalNetworkAccess.SkipDomains == ["wsp.b-trust.bg", "test.b-trust.bg"] and
	.Certificates.Install[-1] == "/opt/btrustbiss/lib/app/BTrustCA/root/biss-localhost-linux.cer" and
	.Preferences["security.osclientcerts.autoload"].Value == false' "$TEST_ROOT/policies.json" >/dev/null
firefox_merge_feature_policies <"$TEST_ROOT/policies.json" >"$TEST_ROOT/policies-again.json"
cmp "$TEST_ROOT/policies.json" "$TEST_ROOT/policies-again.json"

# Review the actual udev rule without installing it or touching the USB bus.
"$files/usr/local/bin/system-btrust-usb" rule ABCD 0123 token-01 >"$TEST_ROOT/usb.rules"
rg -Fq 'ATTR{idVendor}=="abcd", ATTR{idProduct}=="0123", ATTR{serial}=="token-01"' "$TEST_ROOT/usb.rules"
rg -Fq 'TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="system-btrust-usb@.service"' "$TEST_ROOT/usb.rules"
if "$files/usr/local/bin/system-btrust-usb" rule abcd 0123 'bad*serial' >/dev/null 2>&1; then exit 1; fi
if "$files/usr/local/bin/system-btrust-usb" rule not-an-id 0123 >/dev/null 2>&1; then exit 1; fi
"$files/usr/local/bin/system-btrust-usb" rule 31aa 7001 >"$TEST_ROOT/detected.rules"
rg -v '^#' "$files/etc/udev/rules.d/71-system-btrust.rules" | sed '/^$/d' >"$TEST_ROOT/default.rules"
cmp "$TEST_ROOT/detected.rules" "$TEST_ROOT/default.rules"
if rg -q 'ATTR\{serial\}' "$TEST_ROOT/default.rules"; then exit 1; fi
rg -q '^Exec=/usr/local/bin/system-btrust start$' "$files/usr/share/system-btrust/btrustbiss-BISS.desktop"
if rg -q '^Hidden=true$' "$files/usr/share/system-btrust/btrustbiss-BISS.desktop"; then exit 1; fi

# BISS gets physical-token defaults; unrelated settings survive repeat launches.
env HOME="$TEST_ROOT/settings" "$files/usr/local/libexec/system-btrust-settings"
env HOME="$TEST_ROOT/settings" python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
path = Path.home() / 'AppData/Roaming/BISS/Settings.xml'
root = ET.parse(path).getroot()
assert {e.get('key'): e.text for e in root}['osStarted'] == 'false'
ET.SubElement(root, 'entry', key='custom').text = 'retain me'
path.write_bytes(b'<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">\n' + ET.tostring(root))
PY
env HOME="$TEST_ROOT/settings" "$files/usr/local/libexec/system-btrust-settings"
env HOME="$TEST_ROOT/settings" python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
root = ET.parse(Path.home() / 'AppData/Roaming/BISS/Settings.xml').getroot()
values = {e.get('key'): e.text for e in root}
assert values['signAPI'] == 'PKCS11'
assert values['pkcs11Path'] == '/usr/lib/pkcs11/libIDPrimePKCS11.so'
assert values['custom'] == 'retain me'
PY

# Exercise real NSS databases using a harmless installed PKCS#11 library and
# disposable certificates; no token, live browser profile, or daemon is touched.
library=
for path in /usr/lib/libnssckbi.so /usr/lib64/libnssckbi.so; do
	[[ ! -r $path ]] || { library=$path; break; }
done
if command -v certutil >/dev/null && command -v modutil >/dev/null && [[ -n $library ]]; then
	export BTRUST_PKCS11_LIBRARY=$library BTRUST_APP_DIR=$TEST_ROOT/payload
	mkdir -p "$BTRUST_APP_DIR/BTrustCA"/{root,oper} "$TEST_ROOT/bin"
	roots=(B-TrustRootQCA.cer B-TrustRootACA.cer RootCA5_PEM.cer biss-localhost-linux.cer)
	intermediates=(B-TrustOperationalQCA.cer B-TrustOperationalACA.cer OperCA5QES_PEM.cer OperCA5AES_PEM.cer)
	for name in "${roots[@]}" "${intermediates[@]}"; do
		directory=root
		[[ $name != *Operational* && $name != OperCA* ]] || directory=oper
		openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -x509 -days 1 \
			-subj "/CN=$name" -keyout "$TEST_ROOT/key" -out "$BTRUST_APP_DIR/BTrustCA/$directory/$name" \
			>/dev/null 2>&1
	done
	# Control the open-browser check without launching a browser in the real home.
	# shellcheck disable=SC2016 # expanded by the fixture when it runs
	printf '#!/bin/sh\nexit "${TEST_BROWSER_RUNNING:-1}"\n' >"$TEST_ROOT/bin/pgrep"
	chmod +x "$TEST_ROOT/bin/pgrep"
	setup() {
		env PATH="$TEST_ROOT/bin:$PATH" HOME="$1" XDG_DATA_HOME="$1/.local/share" \
			XDG_STATE_HOME="$1/.local/state" "$files/usr/local/libexec/system-btrust-browser-setup"
	}
	setup "$TEST_ROOT/fresh"
	db=$TEST_ROOT/fresh/.local/share/pki/nssdb
	certutil -L -d "sql:$db" >"$TEST_ROOT/certificates"
	for name in "${roots[@]}"; do rg -q "B-Trust/${name}[[:space:]]+C,," "$TEST_ROOT/certificates"; done
	for name in "${intermediates[@]}"; do rg -q "B-Trust/${name}[[:space:]]+,," "$TEST_ROOT/certificates"; done
	modutil -list 'B-Trust IDPrime' -dbdir "sql:$db" >/dev/null
	sha256sum "$db"/* >"$TEST_ROOT/db-before"
	# Already-configured stores are not touched even with a browser running.
	TEST_BROWSER_RUNNING=0 setup "$TEST_ROOT/fresh"
	sha256sum "$db"/* >"$TEST_ROOT/db-after"
	cmp "$TEST_ROOT/db-before" "$TEST_ROOT/db-after"
	# A first setup fails before creating/modifying the browser database.
	if TEST_BROWSER_RUNNING=0 setup "$TEST_ROOT/open" >"$TEST_ROOT/open.log" 2>&1; then exit 1; fi
	rg -q 'Close Chromium' "$TEST_ROOT/open.log"
	[[ ! -e $TEST_ROOT/open/.local/share/pki/nssdb ]]
	# Pending certificate updates also fail before writing an existing store.
	printf '\n' >>"$BTRUST_APP_DIR/BTrustCA/root/B-TrustRootQCA.cer"
	if TEST_BROWSER_RUNNING=0 setup "$TEST_ROOT/fresh" >"$TEST_ROOT/update.log" 2>&1; then exit 1; fi
	sha256sum "$db"/* >"$TEST_ROOT/db-after"
	cmp "$TEST_ROOT/db-before" "$TEST_ROOT/db-after"
	setup "$TEST_ROOT/fresh"
	# Legacy location and an old installer's module registration are retained.
	db=$TEST_ROOT/legacy/.pki/nssdb
	mkdir -p "$db"
	certutil -N --empty-password -d "sql:$db"
	modutil -add 'libIDPrimePKCS11.so' -libfile "$library" -dbdir "sql:$db" -force >/dev/null
	setup "$TEST_ROOT/legacy"
	[[ ! -e $TEST_ROOT/legacy/.local/share/pki/nssdb ]]
	modutil -list 'libIDPrimePKCS11.so' -dbdir "sql:$db" >/dev/null
	if modutil -list 'B-Trust IDPrime' -dbdir "sql:$db" >/dev/null 2>&1; then exit 1; fi
else
	printf 'B-Trust NSS checks skipped: install NSS command-line tools to exercise real databases.\n'
fi

# The executable overlays must retain their modes through module copy.
for path in usr/local/bin/system-btrust usr/local/bin/system-btrust-usb usr/local/libexec/system-btrust-browser-setup usr/local/libexec/system-btrust-maintain usr/local/libexec/system-btrust-bind-usb; do
	bash -n "$files/$path"
	[[ $(stat -c %a "$files/$path") == 755 ]]
done
[[ $(stat -c %a "$files/usr/local/libexec/system-btrust-settings") == 755 ]]
if command -v desktop-file-validate >/dev/null; then
	desktop-file-validate "$files/usr/share/system-btrust/btrustbiss-BISS.desktop"
fi
printf 'B-Trust module, policies, settings, and NSS: ok\n'
