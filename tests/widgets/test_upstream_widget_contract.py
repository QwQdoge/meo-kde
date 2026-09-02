import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "widgets/upstream/first-phase.json"


class UpstreamWidgetContractTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.upstream_root = REPO_ROOT / self.manifest["upstream"]["path"]

    def test_phase_one_is_an_explicit_eight_widget_allowlist(self):
        expected_directories = {
            "weather", "calendar", "digital-clock", "music-player",
            "battery", "notes", "system-monitor", "photos",
        }
        self.assertEqual(
            {widget["sourceDirectory"] for widget in self.manifest["widgets"]},
            expected_directories,
        )
        self.assertEqual(self.manifest["excluded"], ["launcher", "control-center"])

    def test_fork_metadata_and_gpl_source_are_present(self):
        self.assertEqual(self.manifest["upstream"]["license"], "GPL-3.0")
        self.assertTrue((self.upstream_root / "LICENSE").is_file())
        self.assertIn(
            "GNU GENERAL PUBLIC LICENSE",
            (self.upstream_root / "LICENSE").read_text(encoding="utf-8"),
        )

    def test_manifest_matches_the_upstream_plasma_package_ids(self):
        for widget in self.manifest["widgets"]:
            metadata_path = self.upstream_root / widget["sourceDirectory"] / "metadata.json"
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            self.assertEqual(metadata["KPlugin"]["Id"], widget["pluginId"])
            self.assertEqual(metadata["KPlugin"]["License"], "GPL-3.0")

    def test_meoui_is_the_only_shared_visual_module(self):
        visual_module = self.manifest["visualModule"]
        self.assertEqual(visual_module["uri"], "MeoUI")
        self.assertEqual(visual_module["installPath"], "/usr/lib/qt6/qml/MeoUI")
        self.assertIn("not installable", self.manifest["packagingGate"])


if __name__ == "__main__":
    unittest.main()
