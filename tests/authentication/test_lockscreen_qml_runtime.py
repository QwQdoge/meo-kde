"""Headless Qt runtime coverage for the lock-screen visual adapters.

This deliberately instantiates only theme-local, presentation-only QML. It
does not claim to exercise KScreenLocker, PAM, a compositor, or a live Plasma
session; those remain separate runtime acceptance concerns.
"""

from pathlib import Path
import tempfile
import unittest

from PySide6.QtCore import QObject, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent


REPO_ROOT = Path(__file__).resolve().parents[2]
LOCKSCREEN = REPO_ROOT / "themes/look-and-feel/org.meo.desktop/contents/lockscreen"
MEO_UI = REPO_ROOT.parent / "meo-ui"


class LockScreenQmlRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.application = QGuiApplication.instance() or QGuiApplication(
            ["meo-lockscreen-qml-runtime"]
        )

    def create_component(self, name):
        # The development checkout is itself the MeoUI module source. Create
        # the standard import-root layout without copying or modifying it.
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        import_root = Path(directory.name)
        (import_root / "MeoUI").symlink_to(MEO_UI, target_is_directory=True)
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(import_root))
        component = QQmlComponent(engine, QUrl.fromLocalFile(str(LOCKSCREEN / name)))
        self.assertFalse(component.isError(), "\n".join(error.toString() for error in component.errors()))
        item = component.create()
        self.assertIsNotNone(item, "\n".join(error.toString() for error in component.errors()))
        self.application.processEvents()
        return engine, component, item

    def test_dynamic_clock_and_authentication_adapters_instantiate(self):
        for component_name in (
            "MeoLockScreenClock.qml",
            "MeoLockScreenPasswordField.qml",
            "MeoLockScreenAuthCard.qml",
        ):
            with self.subTest(component=component_name):
                engine, component, item = self.create_component(component_name)
                self.assertGreater(item.property("implicitWidth"), 0)
                self.assertGreater(item.property("implicitHeight"), 0)
                item.deleteLater()
                component.deleteLater()
                engine.deleteLater()

    def test_password_pill_exposes_its_qt_textfield_and_submit_target(self):
        engine, component, field = self.create_component("MeoLockScreenPasswordField.qml")
        self.assertFalse(field.property("passwordVisible"))
        self.assertIsNotNone(field.findChild(QObject, "meoLockScreenSubmitButton"))
        field.setProperty("passwordVisible", True)
        self.application.processEvents()
        self.assertTrue(field.property("passwordVisible"))
        field.deleteLater()
        component.deleteLater()
        engine.deleteLater()

    def test_auth_card_failure_motion_is_safe_without_a_locker_backend(self):
        engine, component, card = self.create_component("MeoLockScreenAuthCard.qml")
        card.setProperty("active", True)
        card.triggerFailure()
        self.application.processEvents()
        self.assertTrue(card.property("active"))
        card.deleteLater()
        component.deleteLater()
        engine.deleteLater()


if __name__ == "__main__":
    unittest.main()
