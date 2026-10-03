from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / "defaults/sessions/meoarch-wayland.desktop"
PKGBUILD = ROOT / "packaging/arch/PKGBUILD"


class MeoArchWaylandSessionTests(unittest.TestCase):
    def test_session_is_a_named_plasma_wayland_entry(self):
        content = SESSION.read_text(encoding="utf-8")
        self.assertIn("Name=MeoArch (Wayland)", content)
        self.assertIn("Exec=/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland", content)
        self.assertIn("TryExec=/usr/bin/startplasma-wayland", content)
        self.assertNotIn("DesktopNames=", content)

    def test_arch_package_installs_display_manager_session_entry(self):
        content = PKGBUILD.read_text(encoding="utf-8")
        self.assertIn(
            '"${workspace}/defaults/sessions/meoarch-wayland.desktop"', content
        )
        self.assertIn(
            '"${pkgdir}/usr/share/wayland-sessions/meoarch-wayland.desktop"',
            content,
        )


if __name__ == "__main__":
    unittest.main()
