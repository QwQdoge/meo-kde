"""Security and UI contracts for Meo KDE authentication surfaces."""

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
AUTH = REPO_ROOT / "native/authentication"


class AuthenticationAgentTests(unittest.TestCase):
    def test_native_build_includes_the_meo_polkit_agent(self):
        top_level = (REPO_ROOT / "native/CMakeLists.txt").read_text(encoding="utf-8")
        cmake = (AUTH / "CMakeLists.txt").read_text(encoding="utf-8")

        self.assertIn("add_subdirectory(authentication)", top_level)
        self.assertIn("find_package(PolkitQt6-1 REQUIRED)", cmake)
        self.assertIn("PolkitQt6-1::Agent", cmake)
        self.assertIn("KF6::WindowSystem", cmake)
        self.assertIn("meo-polkit-agent", cmake)

    def test_agent_has_bounded_retry_timeout_and_secret_cleanup(self):
        header = (AUTH / "authenticationcontroller.h").read_text(encoding="utf-8")
        source = (AUTH / "authenticationcontroller.cpp").read_text(encoding="utf-8")
        main = (AUTH / "main.cpp").read_text(encoding="utf-8")

        self.assertIn("MaximumAttempts = 3", header)
        self.assertIn("RequestTimeoutMs = 5 * 60 * 1000", header)
        self.assertIn("response.fill(QChar(u'\\0'))", source)
        self.assertIn("m_cookie.fill(QChar(u'\\0'))", source)
        self.assertIn("emit clearResponseRequested()", source)
        self.assertIn("PR_SET_DUMPABLE", main)
        self.assertIn("setInitialProperties", main)
        self.assertIn("QSessionManager::RestartNever", main)
        self.assertNotIn("setContextProperty", main)
        self.assertNotIn("m_attempts = 0;\n    m_errorText.clear()", source)
        self.assertNotIn('qDebug() << response', source)
        self.assertNotIn('qInfo() << response', source)
        self.assertIn("projectedDisplayText", source)

    def test_agent_preserves_kde_activation_compatibility(self):
        header = (AUTH / "authenticationcontroller.h").read_text(encoding="utf-8")
        source = (AUTH / "authenticationcontroller.cpp").read_text(encoding="utf-8")
        main = (AUTH / "main.cpp").read_text(encoding="utf-8")

        self.assertIn('"org.kde.Polkit1AuthAgent"', header)
        self.assertIn("setWindowHandleForAction", header)
        self.assertIn("setActivationTokenForAction", header)
        self.assertIn("KWindowSystem::setMainWindow", source)
        self.assertIn('"XDG_ACTIVATION_TOKEN"', source)
        self.assertIn('"org.kde.polkit-kde-authentication-agent-1"', main)

    def test_authentication_ui_uses_only_meoui_controls(self):
        qml = (AUTH / "qml/AuthenticationDialog.qml").read_text(encoding="utf-8")

        self.assertIn("import MeoUI 1.0", qml)
        self.assertIn("MeoTextField", qml)
        self.assertIn("MeoButton", qml)
        self.assertIn("MeoIconButton", qml)
        self.assertIn("MeoExposedDropdown", qml)
        self.assertIn("MeoLoadingIndicator", qml)
        self.assertNotIn("QtQuick.Controls", qml)
        self.assertNotIn("QQC2.Button", qml)
        self.assertNotIn("QQC2.TextField", qml)
        self.assertIn("responseField.clear()", qml)
        self.assertIn("property var backend", qml)

        smoke = (REPO_ROOT / "validation/authentication-dialog-smoke.qml").read_text(encoding="utf-8")
        self.assertIn("Authentication.AuthenticationDialog", smoke)
        self.assertIn("backend: previewBackend", smoke)

    def test_wifi_secret_prompt_uses_meoui_and_clears_on_close(self):
        qml = (REPO_ROOT / "plasmoids/org.meo.topbar/contents/ui/WifiPasswordDialog.qml").read_text(
            encoding="utf-8"
        )

        self.assertIn("MeoTextField", qml)
        self.assertIn("MeoMotionPopup", qml)
        self.assertIn("isPassword: true", qml)
        self.assertIn("onClosed:", qml)
        self.assertIn("passwordField.clear()", qml)
        self.assertIn("passwordField.passwordVisible = false", qml)
        self.assertNotIn("QtQuick.Controls", qml)

        page = (REPO_ROOT / "plasmoids/org.meo.topbar/contents/ui/WifiPage.qml").read_text(encoding="utf-8")
        self.assertIn("busy: SystemState.networkBusy", page)
        self.assertIn("errorText: SystemState.operationError", page)
        self.assertIn("connected: SystemState.networkConnected", page)

        backend = (REPO_ROOT / "native/system/systemstatehub.cpp").read_text(encoding="utf-8")
        self.assertIn('QStringLiteral("memory")', backend)
        self.assertIn("NetworkManager::Device::stateChanged", backend)
        self.assertIn("connection->save()", backend)
        self.assertIn("discardTemporaryWifiConnection()", backend)
        self.assertNotIn('QStringLiteral("persist"), QStringLiteral("disk")', backend)

    def test_package_replaces_the_stock_agent_without_double_starting(self):
        pkgbuild = (REPO_ROOT / "packaging/arch/PKGBUILD").read_text(encoding="utf-8")
        service = (AUTH / "data/plasma-polkit-agent.service").read_text(encoding="utf-8")
        autostart = (AUTH / "data/polkit-kde-authentication-agent-1.desktop").read_text(encoding="utf-8")

        self.assertIn("provides=('polkit-kde-agent')", pkgbuild)
        self.assertIn("conflicts=('polkit-kde-agent')", pkgbuild)
        self.assertIn("replaces=('polkit-kde-agent')", pkgbuild)
        self.assertIn("'qt6-base'", pkgbuild)
        self.assertIn("'qt6-declarative'", pkgbuild)
        self.assertIn("ExecStart=/usr/lib/meo-polkit-agent", service)
        self.assertIn("BusName=org.kde.polkit-kde-authentication-agent-1", service)
        self.assertIn("X-systemd-skip=true", autostart)

    def test_notification_content_is_plain_text_and_meoui_driven(self):
        qml = (REPO_ROOT / "qml/MeoKDE/NotificationCenterView.qml").read_text(encoding="utf-8")

        self.assertIn("function plainText(value)", qml)
        self.assertIn("function buttonLabel(value)", qml)
        self.assertIn("slice(0, 16384)", qml)
        self.assertIn("function safeIconName(primary, fallback)", qml)
        self.assertIn("slice(0, 4096)", qml)
        self.assertIn("slice(0, 256)", qml)
        self.assertIn("textFormat: Text.PlainText", qml)
        self.assertIn("bodyExpanded", qml)
        self.assertIn('qsTr("Critical")', qml)
        self.assertIn("MeoButton", qml)
        self.assertIn("MeoIconButton", qml)
        self.assertNotIn("QQC2.Button", qml)

        inline = (REPO_ROOT / "qml/MeoKDE/PopupInlineMessage.qml").read_text(encoding="utf-8")
        self.assertIn("textFormat: Text.PlainText", inline)


if __name__ == "__main__":
    unittest.main()
