from __future__ import annotations

import os
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
INSTALLER = ROOT / "install.sh"
APPLY = ROOT / "setup" / "apply-meo-desktop.sh"
RESET = ROOT / "setup" / "reset-meo-desktop.sh"
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
    def test_root_installer_is_executable_and_has_safe_entry_modes(self) -> None:
        self.assertTrue(INSTALLER.is_file())
        self.assertTrue(os.access(INSTALLER, os.X_OK))

        source = INSTALLER.read_text()
        self.assertIn("prompt_yes_no", source)
        self.assertIn("--full", source)
        self.assertIn("--dry-run", source)
        self.assertIn("MEO_UI_ROOT", source)
        self.assertIn("setup/reset-meo-desktop.sh", source)

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

    def test_source_installer_uses_canonical_meoui_workspace_root(self) -> None:
        source = APPLY.read_text()
        self.assertIn('MEO_UI_ROOT', source)
        self.assertIn('../MeoUI', source)
        self.assertIn('../meo-ui', source)


if __name__ == "__main__":
    unittest.main()
