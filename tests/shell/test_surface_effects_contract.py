"""Transparency and blur are opt-in; popups are solid by default."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class SurfaceEffectsContract(unittest.TestCase):
    def test_defaults_are_solid(self):
        source = read("native/system/shellappearance.cpp")
        self.assertIn('readEntry("SurfaceTransparency", false)', source)
        self.assertIn('readEntry("SurfaceBlur", false)', source)
        self.assertIn("m_transparency && m_blur", read("native/system/shellappearance.h"))

    def test_blur_is_a_compositor_request_not_a_capture(self):
        source = read("native/system/windowblur.cpp")
        self.assertIn("KWindowEffects::enableBlurBehind", source)
        for forbidden in ("grabWindow", "QScreen", "grabToImage"):
            self.assertNotIn(forbidden, source)

    def test_surfaces_consume_the_shared_switch(self):
        self.assertIn("ShellAppearance.transparency", read("qml/MeoKDE/FrostedSurface.qml"))
        self.assertIn("ShellAppearance.blur", read("qml/MeoKDE/DialogBlur.qml"))
        self.assertIn("DialogBlur { dialog: popup }", read("plasmoids/org.meo.topbar/contents/ui/main.qml"))
        self.assertIn("ShellAppearance.transparency", read("qml/MeoKDE/NotificationCenterView.qml"))


if __name__ == "__main__":
    unittest.main()
