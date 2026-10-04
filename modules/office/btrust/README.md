# B-Trust physical QES on demand

`office/btrust` is included in the `office` aggregate used by the Zephyrus host.
It currently supports **Arch x86-64 and Gemalto/IDPrime tokens** using
`sac-core`'s `/usr/lib/pkcs11/libIDPrimePKCS11.so`, matching the existing local
installation. Fedora is explicitly skipped: no Fedora vendor-package adapter
has been implemented or tested. Other card families need their own middleware;
installing this module does not make every B-Trust token compatible.

After provisioning and booting the new root:

1. Log into the desktop, then plug in the QES reader. BISS starts automatically.
2. Open **native Firefox or Chromium** and visit the signing/authentication site.
3. Enter the token PIN when prompted. Unplug the USB reader when finished;
   BISS and PC/SC stop automatically.

The default rule matches the physically observed **Circle CCR7115 ICC** reader,
USB ID **`31aa:7001`**. These identify the model, not an individual unit. No USB
serial number, certificate subject, email, or PIN is included in the repository.
The installed CCID 1.8.4 driver lists this exact reader; the
[upstream CCID catalog](https://ccid.apdu.fr/ccid/limitations.html) lists it too.
No separate Comitex driver is added on top of CCID.

**B-Trust QES** is also available in Applications. Clicking it starts the same
supervised session as USB insertion; its **Stop B-Trust QES** action ends that
session. BISS's signing UI remains available for PIN/confirmation and its
Exit command. `system-btrust start` and `system-btrust stop` are equivalent
terminal commands.
The launcher declares BISS's XWayland window class (`bg.borica.biss.all.a`)
so desktop panels, including zephyrus-shell, can resolve its application icon.
Manual launches also bind to any connected reader tagged by the QES udev rule,
so unplugging it stops that session too. This is a one-time metadata lookup at
launch, not a monitoring process.

BISS 3.46 always opens its control window on Linux; it does not offer a built-in
start-in-tray setting. Its Linux window close button exits BISS and ends the
signing session, just like its Exit command. This was confirmed by inspecting
the installed application's startup and close handlers on 2026-10-05; the tray
implementation is selected only on other operating systems. No window-hiding
workaround is installed. `system-btrust status` shows the session's state.
With an existing home, close Chromium/Chrome before the first launch; NSS setup
is automatic. The same applies after an update that changes the packaged
certificates. Later launches can leave browsers open once configuration matches.
Restart an already-open Firefox once after provisioning so it consumes policies.

## What runs, and when

For an existing Arch laptop where the listed packages are already installed,
close Chromium/Chrome and run from this repository:

```bash
sudo modules/office/btrust/apply-live "$USER"
```

The migration backs up affected configuration and NSS state privately under
`/var/lib/system-btrust/backups/`, installs the same managed files as the module,
stops unmanaged BISS/SACMonitor processes and boot services, and merges Firefox
policies without replacing unrelated policies. It does not reinstall packages.
Restart Firefox to consume its new policies. Use Applications immediately, or
reconnect the reader to test USB activation.

- No BISS login startup and no enabled PC/SC boot socket/service.
- A matching USB insertion starts one systemd user service. It configures the real user's
  NSS database and BISS settings, then starts `system-btrust.target`, which
  starts `pcscd.socket` and `pcscd.service`. BISS runs unprivileged in the user
  service with its HTTPS listener bound to `127.0.0.1`.
- BISS exit, explicit Stop, application failure, or graphical-session shutdown
  runs `ExecStopPost`, stopping the target and both PC/SC units, including the
  activation socket. Keeping a browser open does not keep PC/SC alive.
- `sac-core` supplies libraries; `sac-gui`, `SACMonitor`, and `SACSrv` are not
  installed by this module. Existing BISS/SACMonitor login entries are hidden.
- A generated polkit rule lets only the configured installation user **start
  and stop this exact target**, without an administrator password. It grants
  no permission to manage arbitrary services. Cleanup can work even when the
  desktop session has become inactive.

This module owns the PC/SC lifecycle for this single-user installation. Stopping
QES also disconnects other PC/SC clients. If another application needs a permanent
smart-card service, reconcile that policy before enabling it. A stock Arch
`pcscd` unit uses `--auto-exit`; this module removes that flag so PC/SC stays
available throughout the requested BISS session, and stops it explicitly at exit.
No USB power, kernel, fan, or laptop power policy is changed.

## Browser configuration

**Firefox:** a feature policy is merged into the existing native policies,
preserving extension/search settings. It registers IDPrime for all Firefox
profiles, disables `security.osclientcerts.autoload` per B-Trust's instructions,
and installs the three production B-Trust root CAs plus BISS's localhost root.
Firefox reapplies feature policies if its module is run later in the graph.

Firefox 153+ also gates public websites' access to device apps/services. The
feature policy allows the official `wsp.b-trust.bg` signing site and
`test.b-trust.bg` test site to reach local services through
[`LocalNetworkAccess.SkipDomains`](https://firefox-admin-docs.mozilla.org/reference/policies/localnetworkaccess/).
Other signing portals still need their own Device apps and services permission
(or an explicit source-domain exception). No global `localhost` exception is
installed: that would grant every website access to local services. A working
certificate import alone does not grant this separate site permission.

**Chromium:** first launch initializes/configures the NSS shared database.
An existing `~/.pki/nssdb` takes precedence; otherwise it uses
`${XDG_DATA_HOME:-~/.local/share}/pki/nssdb`, matching Chromium M146 onward.
Production roots and the BISS localhost root get SSL CA trust (`C,,`);
operational certificates are imported as intermediates without CA trust (`,,`).
Test roots and OCSP certificates are not made trust anchors. An equivalent
IDPrime registration from the old installer is retained without adding a second
copy. No Firefox profile database is edited, no existing NSS database is replaced,
and database files are never shipped as home defaults. A fingerprint stamp lets
later launches skip database changes; pending changes fail if Chromium/Chrome
is already running. Use ordinary default browser data paths; custom browser
`--user-data-dir`/NSS configurations are outside this integration.

Certificates come from the checksummed BISS package, not from an unchecked
download during module application. PINs and private keys remain on the token.
Certificate trust and browser module registrations persist between signing
sessions; the running services stop. Removing the module does not automatically
erase certificates already imported into a persistent browser profile/database.

**Chrome:** this repository's Chrome is a Flatpak. Host PKCS#11 libraries cannot
be assumed compatible or accessible inside its runtime. Chrome Flatpak remains
unchanged and is excluded from this QES integration. A separately installed
native Chrome using the same NSS database may work, but is not part of the
validated configuration. Use Firefox or Chromium here.

## Activation on USB insertion

This uses the existing kernel/udev/systemd event path, with **no polling process
or additional USB watcher**. The CCR7115 model rule is installed by default;
there is no enable command required after provisioning. To use a different
reader, identify its USB ID with `lsusb` (the `vvvv:pppp` pair), then run:

```bash
sudo system-btrust-usb enable vvvv pppp
# Optional: match just one physical unit when it exposes a USB serial number.
sudo system-btrust-usb enable vvvv pppp SERIAL
```

Reconnect the device **after desktop login**. The generated rule tags only the
matching USB device and requests `system-btrust-usb@.service` in the user manager.
systemd fills its instance with the escaped sysfs path. The unit binds to both
that device and the BISS service: unplugging the matched USB device stops BISS,
whose cleanup stops PC/SC. Manual Exit still stops the session; reinsert the
device or use `system-btrust start` to start again. Existing desktop session integration
must have exported `DISPLAY`/`XAUTHORITY` to the systemd user manager; the terminal
start command also imports them. If insertion fails, test `system-btrust start` and
inspect the journal below.

USB matching detects **reader/token removal**, not removal of a smart card from
a reader that remains plugged in. Configure one QES device, not several readers
with the same ID: removing one matched device stops the shared signing session.
The default uses the observed reader's public model IDs. Local changes made with
`system-btrust-usb` are preserved across clean-root rebuilds, including an explicit
disabled state. Keep a unique USB serial, if needed, in this local rule rather
than committing it to the public repository.

```bash
sudo system-btrust-usb disable
system-btrust stop
```

Disabling the rule prevents future insertions from starting QES; the explicit
Stop above ends any current session. Replug after changing rules. Devices already
present before login are not promised to trigger the GUI automatically.

## Verification and troubleshooting

```bash
journalctl --user -u system-btrust.service -u 'system-btrust-usb@*'
systemctl status system-btrust.target pcscd.service pcscd.socket
modutil -list -dbdir "sql:$HOME/.local/share/pki/nssdb"
# Use ~/.pki/nssdb instead when that legacy directory already exists.
```

With BISS running, `pcsc_scan` should list the reader and inserted card.
`pkcs11-tool --module /usr/lib/pkcs11/libIDPrimePKCS11.so --list-slots`
checks middleware discovery without requesting a PIN. Firefox's `about:policies`
should show the security-device/certificate policies; Chromium's
`chrome://certificate-manager/` should show the imported authorities. Test
authentication at [B-Trust's test site](https://test.b-trust.bg/) and an actual
signing workflow at [B-Trust online signing](https://wsp.b-trust.bg/WSP/).

After Exit, verify **all three** system units above are inactive and the user
service is inactive. Reboot with the token disconnected and check that nothing
starts until the matching reader is inserted. Separately check insertion/removal.

Repository tests cover policy merging, NSS initialization/reuse, certificate
trust, refusal to modify an open browser's store, BISS settings, and module plans.
The installed IDPrime library and BISS 3.46 certificates were also loaded into a
disposable NSS database. Live laptop checks on 2026-10-04 confirmed application
command startup, the HTTPS listener restricted to loopback, CCR7115 discovery
by PC/SC, clean explicit Stop with the daemon/socket/target all inactive, and the
maintenance hook preserving an active requested session. Java's normal SIGTERM
exit status 143 is treated as success. **End-to-end authentication, signing,
GUI Exit/logout, and physical USB removal/reinsertion have not yet been tested.**

## Sources checked 2026-10-04

- [B-Trust software and current Linux instructions](https://www.b-trust.bg/services/software)
- [Firefox Linux guide](https://www.b-trust.bg/attachments/BtrustPrivateFile/99/docs/Instruktsiya-za-instalirane-i-nastroyki-na-Mozilla-Firefox-za-LinuxOS.pdf)
- [Chrome Linux guide](https://www.b-trust.bg/attachments/BtrustPrivateFile/102/docs/Instruktsiya-za-instalirane-i-nastroyki-na-Google-Chome-za-LinuxOS.pdf)
- [BISS instructions](https://www.b-trust.bg/attachments/BtrustPrivateFile/41/docs/Instruction-BISS.pdf)
- [Mozilla SecurityDevices](https://firefox-admin-docs.mozilla.org/reference/policies/securitydevices/)
  and [Certificates policies](https://firefox-admin-docs.mozilla.org/reference/policies/certificates/)
- [Chromium NSS database selection](https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/docs/linux/cert_management.md)
- [systemd device activation](https://github.com/systemd/systemd/blob/main/man/systemd.device.xml)
- [AUR BISS recipe](https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=btrustbiss)
  and [SafeNet core recipe](https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=sac-core)

The vendor guide names `libeTPkcs11.so`, but the current SafeNet AUR package removes
that legacy alias and installs IDPrime/eToken libraries separately. This module
uses the installed IDPrime path from the working local setup. The AUR BISS hook
still enables PC/SC and copies a login autostart entry, so module application
undoes both. An ordinary mutable-system reinstall/update of `btrustbiss` can run
that hook again; the module's Pacman post-transaction hook restores the launcher,
hidden autostart entries and disabled boot units, and stops services that were
started outside an explicit QES session. The library/package split is intentional; a vendor guide's
boot-enabled service is not necessary evidence for running it continuously.
