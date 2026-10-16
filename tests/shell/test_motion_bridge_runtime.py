"""Exercise the installed QML naming seam in an isolated GUI process."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MotionBridgeRuntimeTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("MEO_RUNTIME_QML_TESTS") == "1",
                         "requires built Meo.System; covered by native/system CI")
    def test_shell_amplitudes_follow_the_shared_motion_policy(self):
        result = subprocess.run([sys.executable, __file__, "--probe"],
                                env=dict(os.environ, QT_QPA_PLATFORM="offscreen"),
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


def probe():
    from PySide6.QtCore import QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlEngine, QQmlComponent

    with tempfile.TemporaryDirectory() as directory:
        os.environ["HOME"] = directory
        os.environ["XDG_CONFIG_HOME"] = str(Path(directory) / "config")
        os.environ["XDG_CACHE_HOME"] = str(Path(directory) / "cache")
        os.environ["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=" + directory + "/no-session-bus"
        app = QGuiApplication(["motion-bridge-test"])
        (Path(directory) / "MeoUI").symlink_to(
            Path(os.environ.get("MEOUI_SOURCE_DIR", str(ROOT.parent / "meo-ui"))),
            target_is_directory=True)
        engine = QQmlEngine()
        engine.addImportPath(directory)
        engine.addImportPath(str(ROOT / "qml"))
        if os.environ.get("MEO_SYSTEM_IMPORT_ROOT"):
            engine.addImportPath(os.environ["MEO_SYSTEM_IMPORT_ROOT"])
        component = QQmlComponent(engine)
        component.setData(b'''import QtQml
import MeoKDE 1.0 as KDE
import MeoUI 1.0 as UI
QtObject {
    property var shellValues: [KDE.MeoMotion.popupOffset("pixel"), KDE.MeoMotion.pageOffset("calm")]
    property var sharedValues: [UI.MeoMotion.popupOffset("pixel"), UI.MeoMotion.pageOffset("calm")]
}''', QUrl())
        item = component.create()
        if item is None:
            raise RuntimeError("\n".join(error.toString() for error in component.errors()))
        if item.property("shellValues").toVariant() != item.property("sharedValues").toVariant():
            raise RuntimeError("Shell motion amplitudes do not match MeoUI")
        item.deleteLater()
        app.processEvents()


if __name__ == "__main__":
    probe()
