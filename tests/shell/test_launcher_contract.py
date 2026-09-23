from pathlib import Path
import unittest

REPO_ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = REPO_ROOT / "plasmoids/org.meo.shelf/contents/ui/LauncherPopup.qml"


class LauncherContractTests(unittest.TestCase):
    def setUp(self):
        self.source = LAUNCHER.read_text(encoding="utf-8")

    def test_launcher_reuses_plasma_models(self):
        self.assertIn("Kicker.RootModel", self.source)
        self.assertIn("Kicker.RunnerModel", self.source)
        self.assertIn("Kicker.RecentUsageModel", self.source)
        self.assertIn("rootAppModel.favoritesModel", self.source)
        self.assertNotIn("FolderListModel", self.source)
        self.assertNotIn(".desktop", self.source)

    def test_launcher_keeps_meo_motion_and_caelestia_style_selection(self):
        self.assertIn("highlightFollowsCurrentItem: false", self.source)
        self.assertIn("Behavior on y", self.source)
        self.assertIn("MeoMotion.stateChange", self.source)
        self.assertIn("MeoTheme.motionEasingEmphasizedDecelerate", self.source)
        self.assertNotRegex(
            self.source,
            r"radius:\s*MeoTheme\.shape(?:Medium|Large|ExtraLarge)\b",
        )

    def test_launcher_keyboard_navigation_is_search_first(self):
        for token in (
            "Qt.Key_J",
            "Qt.Key_K",
            "Qt.Key_PageDown",
            "Qt.Key_PageUp",
            "Keys.onEscapePressed: launcherPopup.close()",
        ):
            self.assertIn(token, self.source)

    def test_search_surface_stays_below_launcher_content(self):
        self.assertLess(
            self.source.index("id: contentHost"),
            self.source.index("id: searchField"),
        )
        self.assertIn('searchField.text = ""', self.source)


if __name__ == "__main__":
    unittest.main()
