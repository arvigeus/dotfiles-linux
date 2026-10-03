# Installer and desktop VM validation

Use separate disposable disks and UEFI variable files for each test. Never point
the VM or bootstrap at a host disk. `hosts/vm.sh` selects a small real integration
stack: base, connectivity/audio, chosen desktop, Firefox and Python development.
It omits the workstation's gaming/laptop policy and large application collection.
It is a test profile, not proof that every workstation application succeeds.

## Run the real installer

```bash
cp .vm.env.example /tmp/dotfiles-vm.env
# Set SOURCE_ISO, VM_DISK and VM_VARS to your disposable test files.
CONFIG_FILE=/tmp/dotfiles-vm.env ./vm/create.sh
CONFIG_FILE=/tmp/dotfiles-vm.env ./vm/run-installer.sh
```

Optional helper settings are `VM_HEADLESS=true`, `VM_SSH_PORT=2229`,
`VM_QMP_SOCKET=vm/test-qmp.sock` and `VM_LOG_DIR=vm/logs`. SSH forwarding binds
only localhost. The scripts do not enable SSH or inject credentials into the
installed system. Enable VM-only access explicitly if needed. Hardware
acceleration is selected when `/dev/kvm` is available; software emulation is
substantially slower.

Inside the live guest:

```bash
mkdir -p /root/setup
mount -t 9p -o trans=virtio,version=9p2000.L setup /root/setup
cd /root/setup
script -q -e -f /root/bootstrap.log -c \
  'bash bootstrap.sh --healthchecks --non-interactive --disk /dev/vda --host-profile vm --desktop hyprland --hostname vm-hyprland'
```

Type the complete disk path for destruction, then use the native LUKS/password
prompts. `--yes` may be used only as the explicit disposable-disk automation
opt-in. Change `--desktop plasma` and use a different disk/vars pair for Plasma.
Fedora Hyprland fails preflight; Fedora Plasma needs its own native installer ISO.

Before powering off, inspect the actual target root and save any live transcript
locally. Boot with `vm/run.sh`, unlock LUKS and log in through the selected login
manager. Mount the share again if necessary, then run `bash vm/verify.sh` inside
the guest. It checks persisted desktop/profile, package separation, actual desktop
and Quickshell processes, Python commands, and loaded Firefox preferences. Close
Firefox before running it: verification launches the managed browser headlessly
without an explicit profile argument and checks both an Arkenfox preference and
local overrides in the resulting `prefs.js`.
A package/healthcheck pass without this boot/login check is incomplete.

For Hyprland also inspect `hyprctl configerrors` from the logged-in desktop,
`journalctl --user -b`, and
`~/.local/state/zephyrus-shell/session.log`. Confirm the visible shell, portal file
picker, polkit prompt and lock/unlock. VM graphics do not establish physical
GA402RK thermal, battery, GPU, VRR/HDR, fan or suspend behavior.

Repeat with `rebuild.sh --healthchecks`, boot the other root, and rerun verification
before treating the two-slot lifecycle as fully validated. The fallback root and
its desktop choice stay unchanged until the next rebuild.

## Retained failure evidence

- `/run/system-provision-state` in the installer and
  `/var/lib/system/provision-state` in the candidate name the last phase/module.
- `/var/log/system/package-plan.tsv` identifies each package's module and source.
- `/var/log/system/package-recipes/` retains resolved PKGBUILD/spec/checksum metadata.
- `/var/log/system/recipe-*.log` records each local recipe's resolution, including failures.
- `/var/log/system/packages.log` records source preparation, build and installation.
- `/var/log/system/module-*.log` records each module's configuration execution.
- `VM_LOG_DIR` retains the guest serial output. `script` captures interactive live
  installer output; keep real credentials out of any shared transcript.

For Arkenfox, verify the package installation and native Firefox configuration:

```bash
pacman -Q arkenfox-user.js
pacman -Ql arkenfox-user.js
stat /usr/share/arkenfox-user.js/user.js
stat /usr/lib/firefox/arkenfox.cfg /usr/lib/firefox/defaults/pref/arkenfox.js
```

On Fedora use `rpm -q`/`rpm -ql` and `/usr/lib64/firefox` instead. Fedora's
fallback RPM is resolved automatically; Arch uses AUR. Trace package failures
through the retained package plan and logs. The module checks for a nonempty
readable template before generating AutoConfig and policies, and repeats that
prerequisite in its healthcheck.

A present template is not proof that Firefox consumes its preferences. Launch
the distribution's ordinary Firefox without `--profile`, inspect its selected
profile in `about:support`, and check effective preferences in `about:config`.
`about:policies` shows add-on/search policy status. `vm/verify.sh` checks the
selected profile's resulting `prefs.js` after a normal headless launch.
The old forced-profile launcher has been removed; see
[Firefox configuration](desktops.md#firefox-configuration).

Test results for this change are recorded in [the validation record](validation-2026-10-01.md).
