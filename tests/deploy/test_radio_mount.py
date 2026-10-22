"""Mount selection and polling without importing deploy's CLI or touching USB.

Run: python -m unittest discover -s tests/deploy
The two production functions are compiled unchanged from their AST; all drive,
clock, process, and mode-switch boundaries are replaced with in-memory fixtures.
"""

import ast
import ntpath
from pathlib import Path
import posixpath
from types import SimpleNamespace
import unittest
from unittest.mock import Mock


SOURCE = Path(__file__).resolve().parents[2] / ".vscode/scripts/deploy.py"


class Clock:
    def __init__(self):
        self.now = 0

    def monotonic(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


def fixture(volumes=(), windows=True):
    path = ntpath if windows else posixpath
    files, directories = set(), set()
    roots = []
    for root, marker in volumes:
        roots.append(root)
        files.add(path.join(root, marker))
        directories.add(path.join(root, "scripts"))
    if not windows:
        directories.add("/Volumes")
    clock = Clock()
    environment = {
        "os": SimpleNamespace(
            name="nt" if windows else "posix", environ={},
            getenv=lambda key, default="": default,
            listdir=lambda base: [path.basename(root) for root in roots]
            if base == "/Volumes" else [],
            path=SimpleNamespace(join=path.join, normpath=path.normpath,
                                 isfile=files.__contains__, isdir=directories.__contains__),
        ),
        "time": clock,
        "print": Mock(),
        "ethos_serial": Mock(return_value=(0, "", "")),
        "get_ethos_scripts_dir": Mock(return_value=None),
        "_radio_serial_port_present": Mock(return_value=False),
    }
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
    names = {"scan_usb_drives_for_radio", "wait_for_scripts_mount"}
    functions = [node for node in tree.body
                 if isinstance(node, ast.FunctionDef) and node.name in names]
    assert len(functions) == len(names), "production mount functions missing"
    exec(compile(ast.Module(body=functions, type_ignores=[]), str(SOURCE), "exec"), environment)
    return environment, clock


class RadioMountTests(unittest.TestCase):
    def test_sdcard_wins_over_earlier_flash_and_radio_on_both_platforms(self):
        for windows, roots in ((True, ("E:\\", "F:\\", "G:\\")),
                               (False, ("/Volumes/FLASH", "/Volumes/RADIO", "/Volumes/SD"))):
            with self.subTest(windows=windows):
                env, _ = fixture(zip(roots, ("flash.cpuid", "radio.cpuid", "sdcard.cpuid")), windows)
                expected = (ntpath if windows else posixpath).join(roots[2], "scripts")
                self.assertEqual(env["scan_usb_drives_for_radio"](quiet=True), expected)
                self.assertEqual(env["wait_for_scripts_mount"]("suite"), expected)
                env["ethos_serial"].assert_not_called()
                env["get_ethos_scripts_dir"].assert_not_called()

    def test_radio_wins_over_earlier_flash(self):
        env, _ = fixture((("E:\\", "flash.cpuid"), ("F:\\", "radio.cpuid")))
        self.assertEqual(env["scan_usb_drives_for_radio"](quiet=True), "F:\\scripts")

    def test_flash_and_legacy_radio_bin_remain_supported_when_alone(self):
        for marker in ("flash.cpuid", "radio.bin"):
            with self.subTest(marker=marker):
                env, _ = fixture((("E:\\", marker),))
                self.assertEqual(env["scan_usb_drives_for_radio"](quiet=True), "E:\\scripts")

    def test_late_mount_does_not_restart_usb_enumeration(self):
        env, clock = fixture((("F:\\", "sdcard.cpuid"),))
        scan = env["scan_usb_drives_for_radio"]
        env["scan_usb_drives_for_radio"] = lambda quiet: scan(quiet) if clock.now >= 30 else None
        self.assertEqual(env["wait_for_scripts_mount"](timeout=60), "F:\\scripts")
        self.assertEqual(clock.now, 30)
        env["ethos_serial"].assert_not_called()

    def test_debug_port_can_trigger_only_one_resend_before_timeout(self):
        env, clock = fixture()
        env["_radio_serial_port_present"].return_value = True
        with self.assertRaisesRegex(RuntimeError, "within 60s"):
            env["wait_for_scripts_mount"]("suite")
        self.assertEqual(clock.now, 60)
        env["ethos_serial"].assert_called_once_with("suite", "stop")
        self.assertEqual(env["get_ethos_scripts_dir"].call_count, 13)

    def test_unknown_or_absent_serial_never_causes_a_mode_switch(self):
        for present in (None, False):
            with self.subTest(present=present):
                env, clock = fixture()
                env["_radio_serial_port_present"].return_value = present
                with self.assertRaises(RuntimeError):
                    env["wait_for_scripts_mount"](timeout=25)
                self.assertEqual(clock.now, 25)
                env["ethos_serial"].assert_not_called()


if __name__ == "__main__":
    unittest.main()
