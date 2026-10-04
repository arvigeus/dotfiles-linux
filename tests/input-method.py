#!/usr/bin/env python3
"""Exercise the installed controller entry point against fake desktop tools."""

import json
import os
import subprocess
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "modules/hardware/keyboard/input-method/system-input-method"
TOOL = r"""#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
root=Path(os.environ['INPUT_TEST_ROOT'])
p=root/'state.json'
s=json.loads(p.read_text())
args=sys.argv[1:]
name=Path(sys.argv[0]).name
with (root/'calls').open('a') as f: f.write(json.dumps([name,*args])+'\n')
if name=='gdbus':
    method=args[args.index('--method')+1]
    if method.endswith('NameHasOwner'): print('(true,)' if s['running'] else '(false,)')
    elif method.endswith('GetNameOwner'): print("(':1.42',)")
    elif method.endswith('reconfigure'): print('()')
    elif method.endswith('setLayout'): s['keymap']='English (US)'; print('(true,)')
    elif method.endswith('FullInputMethodGroupInfo'):
        s['group_queries']=s.get('group_queries',0)+1
        ready=s['group_queries'] > int(os.environ.get('INPUT_TEST_GROUP_DELAY','0'))
        print(repr(('Vietnamese', 'unikey' if ready else 'keyboard-us', 'us', {}, [])))
elif name=='hyprctl':
    if args==['-j','devices']:
        print(json.dumps({'keyboards':s.get('keyboards', [{'main':True,'active_keymap':s['keymap']}])}))
    elif args[0]=='eval':
        s['pair']='vi' if 'kb_layout="us"' in args[1] else 'bg'
        print('ok')
    elif args[0]=='switchxkblayout': s['keymap']='Bulgarian (phonetic)' if args[-1]=='1' else 'English (US)'
elif name=='systemctl':
    if args[1]=='show':
        print('not-found' if os.environ.get('INPUT_TEST_NO_UNIT') else 'loaded'); sys.exit()
    if args[1]=='start' and os.environ.get('INPUT_TEST_FAIL'):
        print('Simulated service failure',file=sys.stderr); sys.exit(1)
    s['running']=args[1]=='start'
elif name=='kwriteconfig6':
    assert '--notify' in args
    value=args[-1]
    # Emulate KWin reading the notified virtual keyboard desktop entry.
    s['running']=bool(value)
    if value:
        s['launcher']=Path(value).read_text()
elif name=='fcitx5-remote':
    assert s['running'], 'Remote call activated an idle daemon'
    if args==['-e']: s['running']=False
    elif args==['-c']: s['active']=False
    elif args==['-o']: s['active']=not os.environ.get('INPUT_TEST_NO_CONTEXT')
    elif args==['-r']: pass
    elif args==['-g','Vietnamese']: pass
    elif args==['-s','unikey']:
        s['engine']='unikey'
        s['active']=not os.environ.get('INPUT_TEST_NO_CONTEXT')
    elif args==['-n']:
        print(s.get('engine','unikey') if s['active'] else 'keyboard-us')
    elif not args: print('0' if os.environ.get('INPUT_TEST_NO_CONTEXT') else '2' if s['active'] else '1')
p.write_text(json.dumps(s))
"""


class InputMethodTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        tools = self.root / "bin"
        tools.mkdir()
        for name in ("gdbus", "hyprctl", "systemctl", "kwriteconfig6", "fcitx5-remote", "fcitx5"):
            path = tools / name
            path.write_text(TOOL)
            path.chmod(0o755)
        # Host-installed Fcitx tools must never satisfy missing-package cases
        # or accidentally contact the real session.
        for name in ("bash", "python3", "timeout", "dirname", "mkdir", "cat", "mv", "awk", "date", "sleep", "jq", "flock"):
            (tools / name).symlink_to(shutil.which(name))
        self.env = dict(
            os.environ,
            INPUT_TEST_ROOT=str(self.root),
            XDG_CONFIG_HOME=str(self.root / "config"),
            XDG_DATA_HOME=str(self.root / "data"),
            XDG_RUNTIME_DIR=str(self.root / "runtime"),
            XDG_CURRENT_DESKTOP="Hyprland",
            HYPRLAND_INSTANCE_SIGNATURE="test-instance",
            PATH=str(tools),
        )
        engine = self.root / "data/fcitx5/inputmethod/unikey.conf"
        engine.parent.mkdir(parents=True)
        engine.write_text("Name=UniKey\n")
        (self.root / "state.json").write_text(
            json.dumps(
                {
                    "running": False,
                    "active": False,
                    "pair": "bg",
                    "engine": "keyboard-us",
                    "keymap": "English (US)",
                }
            )
        )

    def invoke(self, *args, success=True):
        result = subprocess.run(
            [str(CONTROLLER), *args],
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        return json.loads(result.stdout) if result.stdout.strip() else None

    def calls(self):
        path = self.root / "calls"
        return (
            [json.loads(line) for line in path.read_text().splitlines()]
            if path.exists()
            else []
        )

    def state(self):
        return json.loads((self.root / "state.json").read_text())

    def test_idle_and_configure_do_not_contact_fcitx_or_start_services(self):
        self.invoke("configure", "hyprland")
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.invoke("status")["secondary"], "bg")
        self.assertEqual([call[0] for call in self.calls()], ["systemctl", "hyprctl"])
        self.assertEqual(self.calls()[0][1:3], ["--user", "show"])

    def test_availability_requires_engine_and_service(self):
        self.assertTrue(self.invoke("status")["available"])
        self.env["INPUT_TEST_NO_UNIT"] = "1"
        self.assertFalse(self.invoke("status")["available"])
        del self.env["INPUT_TEST_NO_UNIT"]
        self.env["XDG_DATA_DIRS"] = str(self.root / "empty")
        (self.root / "data/fcitx5/inputmethod/unikey.conf").unlink()
        self.assertFalse(self.invoke("status")["available"])

    def test_status_tracks_keyboard_from_layout_event(self):
        state = self.state()
        state["keyboards"] = [
            {"name": "usb", "main": True, "layout": "us,bg", "active_layout_index": 0},
            {"name": "laptop", "main": False, "layout": "us,bg", "active_layout_index": 1},
        ]
        (self.root / "state.json").write_text(json.dumps(state))
        self.assertEqual(self.invoke("status")["language"], "en")
        self.assertEqual(self.invoke("status", "laptop")["language"], "bg")
        self.assertEqual(self.invoke("status", "unplugged")["language"], "en")

    def test_vietnamese_english_bulgarian_transitions(self):
        self.assertEqual(self.invoke("select", "vi")["language"], "vi")
        self.assertTrue(self.state()["running"])
        self.assertEqual(self.state()["pair"], "vi")
        override = self.root / "runtime/zephyrus-shell/input-language-test-instance.lua"
        self.assertIn('kb_layout="us"', override.read_text())
        self.assertEqual(self.invoke("select", "en")["secondary"], "vi")
        self.assertFalse(self.state()["active"])
        self.invoke("select", "vi")
        starts = [c for c in self.calls() if c[:3] == ["systemctl", "--user", "start"]]
        self.assertEqual(
            len(starts), 1, "Switching back to Vietnamese restarted the daemon"
        )
        self.assertEqual(self.invoke("select", "bg")["language"], "bg")
        self.assertFalse(self.state()["running"])
        self.assertEqual(self.state()["pair"], "bg")
        self.assertIn('kb_layout="us,bg"', override.read_text())
        profile = (self.root / "config/fcitx5/profile").read_text()
        self.assertIn("Name=unikey", profile)
        self.assertNotIn("keyboard-bg", profile)
        self.assertIn("Alt+Shift_L", (self.root / "config/fcitx5/config").read_text())
        self.assertIn(
            "InputMethod=Telex",
            (self.root / "config/fcitx5/conf/unikey.conf").read_text(),
        )

    def test_first_selection_waits_for_configured_group(self):
        self.env['INPUT_TEST_GROUP_DELAY'] = '2'
        result = self.invoke('select', 'vi')
        self.assertEqual(result['language'], 'vi')
        self.assertEqual(self.state()['engine'], 'unikey')
        self.assertEqual(self.state()['group_queries'], 3)
        starts = [c for c in self.calls() if c[:3] == ['systemctl', '--user', 'start']]
        self.assertEqual(len(starts), 1)

    def test_noneditable_context_does_not_disable_vietnamese_mode(self):
        self.invoke('select', 'vi')
        state = self.state()
        state['engine'] = 'keyboard-us'
        (self.root / 'state.json').write_text(json.dumps(state))
        self.assertEqual(self.invoke('status')['language'], 'vi')

    def test_selection_without_any_text_context_preserves_pair_and_mode(self):
        self.env['INPUT_TEST_NO_CONTEXT'] = '1'
        self.assertEqual(self.invoke('select', 'vi')['language'], 'vi')
        self.assertTrue(self.state()['running'])
        self.assertEqual(self.state()['pair'], 'vi')
        english = self.invoke('select', 'en')
        self.assertEqual((english['language'], english['secondary']), ('en', 'vi'))
        config = self.root / 'config/fcitx5/config'
        self.assertIn('ActiveByDefault=False', config.read_text())
        self.assertEqual(self.invoke('select', 'vi')['language'], 'vi')
        self.assertIn('ActiveByDefault=True', config.read_text())

    def test_configure_retains_unrelated_settings_and_is_idempotent(self):
        root = self.root / "config/fcitx5"
        (root / "conf").mkdir(parents=True)
        (root / "config").write_text(
            "[Behavior]\nAutoSavePeriod=12\n[Hotkey/TriggerKeys]\n0=Control+space\n[Other]\nCustom=True\n"
        )
        (root / "conf/unikey.conf").write_text("Macro=False\nInputMethod=VNI\n")
        self.invoke("configure", "hyprland")
        first = (root / "config").read_text()
        self.invoke("configure", "hyprland")
        self.assertEqual(first, (root / "config").read_text())
        self.assertIn("AutoSavePeriod=12", first)
        self.assertIn("Custom=True", first)
        self.assertEqual(first.count("[Behavior]"), 1)
        unikey = (root / "conf/unikey.conf").read_text()
        self.assertIn("Macro=False", unikey)
        self.assertEqual(unikey.count("InputMethod="), 1)
        self.assertIn("InputMethod=Telex", unikey)
        self.assertEqual(self.calls(), [])

    def test_bg_works_without_vietnamese_packages(self):
        (self.root / "bin/fcitx5-remote").unlink()
        self.assertEqual(self.invoke("select", "bg")["language"], "bg")
        self.assertFalse(any(call[0] == "systemctl" for call in self.calls()))
        self.invoke("select", "vi", success=False)
        self.assertFalse(self.state()["running"])
        self.assertEqual(self.state()["pair"], "bg")

    def test_failed_start_restores_bulgarian_pair(self):
        self.env["INPUT_TEST_FAIL"] = "1"
        self.invoke("select", "vi", success=False)
        self.assertEqual(self.invoke("status")["secondary"], "bg")
        self.assertEqual(self.state()["pair"], "bg")
        self.assertFalse(self.state()["running"])

    def test_new_compositor_does_not_restore_vietnamese_request(self):
        self.invoke("select", "vi")
        self.env["HYPRLAND_INSTANCE_SIGNATURE"] = "another-session"
        self.assertEqual(self.invoke("status")["secondary"], "bg")

    def test_apply_seeds_both_desktops_without_starting_services(self):
        stub = self.root / "setup/lib"
        stub.mkdir(parents=True)
        (stub / "module.sh").write_text("""file_write() {
    local mode=0644
    if [[ ${1:-} == -m ]]; then mode=$2; shift 2; fi
    local dest=$1
    [[ $dest == "$HOME"/* ]] || dest="$INPUT_TEST_ROOT/root$dest"
    mkdir -p "$(dirname -- "$dest")"
    cat >"$dest"
    chmod "$mode" "$dest"
}
home_strategy() { :; }
module_entrypoint() { module_apply; }
""")
        (stub / "env.sh").write_text("system_set_env() { :; }\n")
        for distro, kind in (
            ("arch", "hyprland"),
            ("arch", "plasma"),
            ("fedora", "plasma"),
        ):
            with self.subTest(distro=distro, desktop=kind):
                env = dict(
                    self.env,
                    HOME=str(self.root / "home"),
                    XDG_CONFIG_HOME=str(self.root / "home/.config"),
                    MODULE_DIR=str(ROOT / "modules/hardware/keyboard/input-method"),
                    SETUP_ROOT=str(self.root / "setup"),
                    DESKTOP=kind,
                    DISTRO=distro,
                    PATH=str(self.root / "root/usr/local/bin")
                    + os.pathsep
                    + os.environ["PATH"],
                )
                for leaf in ("common", "bg", "vn"):
                    result = subprocess.run(
                        [
                            "bash",
                            str(
                                ROOT
                                / f"modules/hardware/keyboard/input-method/{leaf}.sh"
                            ),
                        ],
                        env=env,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(
                    "Hidden=true",
                    (
                        self.root / "home/.config/autostart/org.fcitx.Fcitx5.desktop"
                    ).read_text(),
                )
                self.assertIn(
                    "Exec=/usr/bin/false",
                    (
                        self.root
                        / "home/.local/share/dbus-1/services/org.fcitx.Fcitx5.service"
                    ).read_text(),
                )
                self.assertNotIn(
                    "[Install]",
                    (
                        self.root
                        / "root/usr/lib/systemd/user/system-vietnamese.service"
                    ).read_text(),
                )
                self.assertIn(
                    "InputMethod=Telex",
                    (self.root / "home/.config/fcitx5/conf/unikey.conf").read_text(),
                )
                if kind == "plasma":
                    layouts = (self.root / "home/.config/kxkbrc").read_text()
                    self.assertIn("LayoutList=us,bg", layouts)
                    self.assertIn("VariantList=,phonetic", layouts)
                    self.assertIn("grp:alt_shift_toggle", layouts)
                else:
                    provider = json.loads(
                        (self.root / "home/.config/zephyrus-shell/input-language.json").read_text()
                    )
                    self.assertEqual(provider["command"], ["/usr/local/bin/system-input-method"])
                    self.assertIn(
                        'kb_variant = ",phonetic"',
                        (
                            self.root / "home/.config/zephyrus-shell/input-method.lua"
                        ).read_text(),
                    )
        self.assertEqual(
            self.calls(), [], "Module apply contacted a running desktop or service"
        )

    def test_plasma_uses_kwin_and_idle_login_launcher_exits(self):
        self.env["XDG_CURRENT_DESKTOP"] = "KDE"
        self.invoke("kwin-launch")
        self.assertFalse(self.state()["running"])
        self.assertEqual(self.invoke("select", "vi")["language"], "vi")
        self.assertIn("kwin-launch", self.state()["launcher"])
        self.assertFalse(any(call[0] == "systemctl" for call in self.calls()))
        self.assertIn("Control+space", (self.root / "config/fcitx5/config").read_text())
        self.assertIn(
            "Allow Overriding System XKB Settings=False",
            (self.root / "config/fcitx5/conf/wayland.conf").read_text(),
        )
        self.invoke("select", "bg")
        self.assertFalse(self.state()["running"])


if __name__ == "__main__":
    unittest.main()
