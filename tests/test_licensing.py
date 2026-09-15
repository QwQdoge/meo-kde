from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class LicensingTests(unittest.TestCase):
    def test_repository_bundles_gpl2_text(self):
        license_text = (ROOT / "assets/licenses/GPL-2.0-or-later.txt").read_text()
        self.assertIn("GNU GENERAL PUBLIC LICENSE", license_text)
        self.assertIn("Version 2, June 1991", license_text)

    def test_meo_desktop_installs_gpl2_text(self):
        recipe = (ROOT / "packaging/arch/PKGBUILD").read_text()
        self.assertIn("'GPL-2.0-or-later'", recipe)
        self.assertIn("assets/licenses/GPL-2.0-or-later.txt", recipe)

    def test_lgpl_notice_is_scoped_to_plasma_patch_package(self):
        notices = (ROOT / "THIRD_PARTY_NOTICES.md").read_text()
        self.assertIn("meo-plasma-desktop", notices)
        self.assertIn("LGPL-2.0-or-later.txt", notices)
        runtime_paragraph = notices.split("The separate", 1)[0]
        self.assertNotIn("LGPL-2.0-or-later", runtime_paragraph)

    def test_plasma_patch_package_installs_lgpl_text(self):
        package_dir = ROOT / "packaging/arch/meo-plasma-desktop"
        recipe = (package_dir / "PKGBUILD").read_text()
        license_text = (package_dir / "LGPL-2.0-or-later.txt").read_text()
        self.assertIn("license=(LGPL-2.0-or-later)", recipe)
        self.assertIn("LGPL-2.0-or-later.txt", recipe)
        self.assertIn("GNU LIBRARY GENERAL PUBLIC LICENSE", license_text)


if __name__ == "__main__":
    unittest.main()
