"""Headless Qt runtime coverage for the lock-screen visual adapters.

This deliberately instantiates only theme-local, presentation-only QML. It
does not claim to exercise KScreenLocker, PAM, a compositor, or a live Plasma
session; those remain separate runtime acceptance concerns.
"""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from PySide6.QtCore import QObject, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent
from PySide6.QtTest import QSignalSpy


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

    def test_clock_places_minutes_below_hours_and_date_below_both(self):
        engine, component, clock = self.create_component("MeoLockScreenClock.qml")
        hours = clock.findChild(QObject, "lockHours")
        minutes = clock.findChild(QObject, "lockMinutes")
        date = clock.findChild(QObject, "lockDate")
        self.assertGreater(minutes.property("y"), hours.property("y"))
        self.assertGreater(date.property("y"), minutes.property("y") + minutes.property("height"))
        self.assertEqual(hours.property("color"), minutes.property("color"))
        clock.deleteLater()
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

    def test_enter_cannot_submit_an_empty_field(self):
        engine, component, field = self.create_component("MeoLockScreenPasswordField.qml")
        requested = QSignalSpy(field.unlockRequested)
        field.accepted.emit()
        self.assertEqual(requested.count(), 0)
        field.setProperty("text", "fixture")
        field.accepted.emit()
        self.assertEqual(requested.count(), 1)
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


class LockScreenTypeResolutionTests(unittest.TestCase):
    """Resolve every lock-screen QML type against the installed Plasma.

    KScreenLocker silently falls back to the stock lock screen when any type
    fails to resolve (Plasma 6.8 removed VirtualKeyboardLoader, which went
    unnoticed because the source-text tests still passed). Linting against the
    real installed modules turns that into a test failure.
    """

    FATAL = ("is not a type", "cannot be used as a type", "was not found. Did you add all imports", "Failed to import", "unresolved type", "Member \"space")

    @unittest.skipUnless(
        Path("/usr/lib/qt6/bin/qmllint").exists(),
        "qmllint is not installed",
    )
    @unittest.skipUnless(Path("/usr/lib/qt6/qml/org/kde/breeze/components").exists(),
                         "Plasma QML modules are not installed")
    def test_every_lockscreen_type_resolves_against_installed_plasma(self):
        qmllint = "/usr/lib/qt6/bin/qmllint"
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "MeoUI").symlink_to(MEO_UI, target_is_directory=True)
            problems = []
            for path in sorted(LOCKSCREEN.glob("*.qml")):
                result = subprocess.run(
                    [qmllint, "-I", directory, "-I", "/usr/lib/qt6/qml", str(path)],
                    capture_output=True, text=True, check=False,
                )
                for line in (result.stdout + result.stderr).splitlines():
                    if any(marker in line for marker in self.FATAL):
                        problems.append(line.strip())
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
