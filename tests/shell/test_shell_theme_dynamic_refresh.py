from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SHELL_THEME = ROOT / "qml" / "MeoKDE" / "MeoShellTheme.qml"


class ShellThemeDynamicRefreshTests(unittest.TestCase):
    def test_shell_theme_listens_for_material_scheme_changes(self) -> None:
        source = SHELL_THEME.read_text(encoding="utf-8")
        self.assertIn("Connections {", source)
        self.assertIn("target: root.materialProvider()", source)
        self.assertIn("function onSchemeChanged()", source)
        self.assertIn("root.sync()", source)


if __name__ == "__main__":
    unittest.main()
