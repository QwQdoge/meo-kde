from __future__ import annotations

import os
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
BOOTSTRAP = ROOT / "bootstrap.sh"
INSTALLER = ROOT / "install.sh"
APPLY = ROOT / "setup" / "apply-meo-desktop.sh"
RESET = ROOT / "setup" / "reset-meo-desktop.sh"
SYSTEM_APPLY = ROOT / "setup" / "apply-meo-system.sh"
SYSTEM_RESET = ROOT / "setup" / "reset-meo-system.sh"
PKGBUILD = ROOT / "packaging" / "arch" / "PKGBUILD"
SESSION_ENTRY = ROOT / "data" / "wayland-sessions" / "meo.desktop"
SESSION_LAUNCHER = ROOT / "tools" / "session" / "startmeo-wayland"

PACKAGED_USER_APPLETS = {
    "org.meo.topbar",
    "org.meo.toptasks",
    "org.meo.time",
    "org.meo.notifications",
    "org.meo.time-notifications",
    "org.meo.timecenter",
    "org.meo.widgetexplorer",
    "org.meo.widget.clock",
    "org.meo.widget.media",
    "org.meo.widget.performance",
}


class InstallerContractTests(unittest.TestCase):
    def test_remote_bootstrap_is_small_launcher(self) -> None:
        self.assertTrue(BOOTSTRAP.is_file())
        self.assertTrue(os.access(BOOTSTRAP, os.X_OK))
        source = BOOTSTRAP.read_text()
        self.assertIn("MEO_KDE_REF", source)
        self.assertIn("/dev/tty", source)
        self.assertIn('exec "${checkout}/install.sh"', source)
        self.assertNotIn("pacman -Syu", source)
        self.assertNotIn("systemctl enable", source)

    def test_root_installer_is_package_first_and_does_not_rewrite_current_plasma(self) -> None:
        self.assertTrue(INSTALLER.is_file())
        self.assertTrue(os.access(INSTALLER, os.X_OK))

        source = INSTALLER.read_text()
        self.assertIn("minimum_safe_version", source)
        self.assertIn("pacman -Si meo-desktop", source)
        self.assertIn("-Syu --needed", source)
        self.assertIn("/usr/share/wayland-sessions/meo.desktop", source)
        self.assertIn("/usr/bin/startmeo-wayland", source)
        self.assertIn("--dry-run", source)
        self.assertNotIn('"${apply_script}"', source)
        self.assertNotIn("--reset-layout", source)
        self.assertNotIn("meo-desktop-apply", source)
        self.assertNotIn("systemctl enable", source)
        self.assertTrue(os.access(SYSTEM_APPLY, os.X_OK))
        self.assertTrue(os.access(SYSTEM_RESET, os.X_OK))

    def test_help_does_not_require_a_plasma_runtime(self) -> None:
        result = subprocess.run(
            [str(INSTALLER), "--help"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("signed `meo-desktop` package", result.stdout)
        self.assertIn("separate \"Meo Desktop\" Wayland login option", result.stdout)
        self.assertIn("--dry-run", result.stdout)

    def test_meo_wayland_session_is_isolated_from_normal_plasma_config(self) -> None:
        self.assertTrue(SESSION_ENTRY.is_file())
        self.assertTrue(SESSION_LAUNCHER.is_file())
        entry = SESSION_ENTRY.read_text()
        launcher = SESSION_LAUNCHER.read_text()
        self.assertIn("Name=Meo Desktop", entry)
        self.assertIn("Exec=/usr/bin/startmeo-wayland", entry)
        self.assertIn('XDG_CONFIG_HOME="${meo_config_home}"', launcher)
        self.assertIn('XDG_STATE_HOME="${meo_state_home}"', launcher)
        self.assertIn("MEO_DESKTOP_SESSION=1", launcher)
        self.assertIn("/usr/bin/startplasma-wayland", launcher)
        self.assertNotIn("/etc/xdg/kdeglobals", launcher)
        self.assertNotIn("~/.config/kdeglobals", launcher)

    def test_source_developer_apply_matches_packaged_user_applet_set(self) -> None:
        apply_source = APPLY.read_text()
        reset_source = RESET.read_text()
        package_source = PKGBUILD.read_text()

        for plugin_id in sorted(PACKAGED_USER_APPLETS):
            with self.subTest(plugin_id=plugin_id):
                self.assertIn(plugin_id, package_source)
                self.assertIn(plugin_id, apply_source)
                self.assertIn(plugin_id, reset_source)

    def test_system_integration_is_explicit_and_reversible(self) -> None:
        apply_source = SYSTEM_APPLY.read_text()
        reset_source = SYSTEM_RESET.read_text()

        for path in (
            "/etc/systemd/zram-generator.conf.d/50-meo-desktop.conf",
            "/etc/gamemode.ini",
            "/etc/system76-scheduler/process-scheduler/meo-cachyos.kdl",
        ):
            self.assertIn(path, apply_source)
            self.assertIn(path, reset_source)

        self.assertIn("power-profiles-daemon.service", apply_source)
        self.assertIn("com.system76.Scheduler.service", apply_source)
        self.assertIn("/var/lib/meo-desktop", apply_source)
        self.assertIn("/var/lib/meo-desktop", reset_source)

    def test_optional_rounded_corner_effect_does_not_block_developer_apply(self) -> None:
        source = APPLY.read_text()
        self.assertIn("Optional KWin rounded-corner effect is missing", source)
        self.assertIn("Continuing without client-surface rounded clipping", source)

    def test_developer_apply_uses_canonical_meoui_workspace_root(self) -> None:
        source = APPLY.read_text()
        self.assertIn('MEO_UI_ROOT', source)
        self.assertIn('../MeoUI', source)
        self.assertIn('../meo-ui', source)


if __name__ == "__main__":
    unittest.main()
