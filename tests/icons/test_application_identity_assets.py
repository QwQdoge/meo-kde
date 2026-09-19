import json
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "assets/icons/application-identities"
MANIFEST_PATH = SOURCE_ROOT / "manifest.json"
SYSTEM_ROOT = ROOT / "themes/icons/MeoSymbols"
EXPECTED = {
    "org.meo.settings.desktop": ("org.meo.settings", "meo-settings"),
    "org.meo.Accounts.Settings.desktop": ("org.meo.Accounts.Settings", "meo-account"),
    "omnistore.desktop": ("org.meo.OmniStore", "omnistore-bin"),
    "org.meo.welcome.desktop": ("org.meo.welcome", "meo-settings"),
}


class ApplicationIdentityAssetsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.entries = {entry["desktopId"]: entry for entry in cls.payload["applications"]}
        cls.system_names = {path.stem.removesuffix("-symbolic")
                            for path in SYSTEM_ROOT.rglob("*.svg")}

    def test_manifest_has_all_p0_private_identities(self):
        self.assertEqual(self.payload["id"], "MeoIconManifest")
        self.assertEqual(self.payload["contractVersion"], "1")
        self.assertEqual(set(self.entries), set(EXPECTED))
        names = []
        for desktop_id, (icon_name, runtime_owner) in EXPECTED.items():
            entry = self.entries[desktop_id]
            self.assertEqual(entry["iconName"], icon_name)
            self.assertEqual(entry["runtimeOwner"], runtime_owner)
            self.assertTrue(entry["overlayEligible"])
            self.assertNotIn(icon_name, self.system_names)
            names.append(icon_name)
        self.assertEqual(len(names), len(set(names)))

    def test_sources_follow_the_contract_and_expose_optical_masters(self):
        for entry in self.entries.values():
            source_paths = [entry["colorSource"], entry["monoGlyphSource"],
                            *entry["opticalMasters"].values()]
            for relative in source_paths:
                path = SOURCE_ROOT / relative
                self.assertTrue(path.is_file(), path)
                source = path.read_text(encoding="utf-8")
                self.assertNotRegex(source, r"\b0\.[0-9]+")
                self.assertNotRegex(source, r"<(?:text|image)\b")
                root = ET.fromstring(source)
                self.assertEqual(root.tag, "{http://www.w3.org/2000/svg}svg")
                self.assertIn("viewBox", root.attrib)
            self.assertEqual(ET.parse(SOURCE_ROOT / entry["colorSource"]).getroot().attrib["viewBox"],
                             "0 0 48 48")
            self.assertEqual(ET.parse(SOURCE_ROOT / entry["monoGlyphSource"]).getroot().attrib["viewBox"],
                             "0 0 48 48")
            for size in ("16", "22", "32"):
                master = SOURCE_ROOT / entry["opticalMasters"][size]
                self.assertEqual(ET.parse(master).getroot().attrib["viewBox"],
                                 f"0 0 {size} {size}")
                self.assertTrue(entry["opticalCorrections"][size])

    def test_color_and_mono_sources_are_deliberately_separate(self):
        for entry in self.entries.values():
            color = (SOURCE_ROOT / entry["colorSource"]).read_text(encoding="utf-8")
            mono = (SOURCE_ROOT / entry["monoGlyphSource"]).read_text(encoding="utf-8")
            self.assertNotEqual(color, mono)
            self.assertNotIn("currentColor", color)
            self.assertIn("currentColor", mono)
            self.assertTrue(re.fullmatch(r"[A-Za-z0-9.]+", entry["iconName"]))

    def test_dynamic_color_refresh_uses_the_package_owned_studio(self):
        source = (ROOT / "native/dynamic-color/main.cpp").read_text(encoding="utf-8")
        self.assertIn('QStringLiteral("/usr/bin/meo-app-icon-studio")', source)
        self.assertNotIn('findExecutable(QStringLiteral("meo-app-icon-studio"))', source)

    def test_legacy_symbols_recipe_does_not_own_the_application_renderer(self):
        recipe = (ROOT / "packaging/arch/meo-icons/PKGBUILD").read_text(encoding="utf-8")
        self.assertNotIn("meo-app-icon-studio", recipe)
        self.assertNotIn("python-pillow", recipe)
        self.assertIn("system semantic icon themes", recipe)


if __name__ == "__main__":
    unittest.main()
