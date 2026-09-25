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


class GuidedInstallerContractTests(unittest.TestCase):
    def test_remote_bootstrap_is_small_interactive_launcher(self) -> None:
        self.assertTrue(BOOTSTRAP.is_file())
        self.assertTrue(os.access(BOOTSTRAP, os.X_OK))
        source = BOOTSTRAP.read_text()
        self.assertIn("MEO_KDE_REF", source)
        self.assertIn("/dev/tty", source)
        self.assertIn('exec "${checkout}/install.sh"', source)
        self.assertNotIn("pacman -Syu", source)
        self.assertNotIn("systemctl enable", source)

    def test_root_installer_is_executable_and_has_safe_entry_modes(self) -> None:
        self.assertTrue(INSTALLER.is_file())
        self.assertTrue(os.access(INSTALLER, os.X_OK))

        source = INSTALLER.read_text()
        self.assertIn("prompt_yes_no", source)
        self.assertIn("--full", source)
        self.assertIn("--dry-run", source)
        self.assertIn("--kde-only", source)
        self.assertIn("sudo pacman -Syu --needed", source)
        self.assertIn("MEO_UI_ROOT", source)
        self.assertIn("setup/reset-meo-desktop.sh", source)
        self.assertIn("setup/reset-meo-system.sh", source)
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
        self.assertIn("Interactive guided installation", result.stdout)
        self.assertIn("--full", result.stdout)

    def test_source_install_matches_packaged_user_applet_set(self) -> None:
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

    def test_optional_rounded_corner_effect_does_not_block_preflight(self) -> None:
        source = APPLY.read_text()
        self.assertIn("Optional KWin rounded-corner effect is missing", source)
        self.assertIn("Continuing without client-surface rounded clipping", source)

    def test_source_installer_uses_canonical_meoui_workspace_root(self) -> None:
        source = APPLY.read_text()
        self.assertIn('MEO_UI_ROOT', source)
        self.assertIn('../MeoUI', source)
        self.assertIn('../meo-ui', source)


if __name__ == "__main__":
    unittest.main()
