"""Exercise the installed QML naming seam rather than inspect its source."""
from pathlib import Path
import tempfile
import unittest

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent

ROOT = Path(__file__).resolve().parents[2]


class MotionBridgeRuntimeTests(unittest.TestCase):
    def test_shell_amplitudes_follow_the_shared_motion_policy(self):
        app = QGuiApplication.instance() or QGuiApplication(["motion-bridge-test"])
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "MeoUI").symlink_to(ROOT.parent / "meo-ui", target_is_directory=True)
            engine = QQmlEngine()
            engine.addImportPath(directory)
            engine.addImportPath(str(ROOT / "qml"))
            component = QQmlComponent(engine)
            component.setData(b'''import QtQml
import MeoKDE 1.0 as KDE
import MeoUI 1.0 as UI
QtObject {
    property var shellValues: [KDE.MeoMotion.popupOffset("pixel"), KDE.MeoMotion.pageOffset("calm")]
    property var sharedValues: [UI.MeoMotion.popupOffset("pixel"), UI.MeoMotion.pageOffset("calm")]
}''', QUrl())
            item = component.create()
            self.assertIsNotNone(item, "\n".join(error.toString() for error in component.errors()))
            self.assertEqual(item.property("shellValues").toVariant(), item.property("sharedValues").toVariant())
            item.deleteLater()
            app.processEvents()
