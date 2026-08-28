import QtQuick
import QtQuick.Window
import "../native/authentication/qml" as Authentication

Window {
    id: harness
    width: 1
    height: 1
    visible: false

    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    QtObject {
        id: previewBackend
        property bool inProgress: true
        property bool busy: false
        property bool echoResponse: false
        property string actionId: "org.freedesktop.packagekit.system-update"
        property string message: "Install trusted system updates"
        property string requesterLabel: "Software management"
        property string prompt: "Password"
        property string errorText: ""
        property string infoText: "Confirm your identity to continue."
        property var identities: ["Meo User", "Administrator"]
        property int selectedIdentityIndex: 0
        property int attemptsRemaining: 3

        signal clearResponseRequested()
        signal focusResponseRequested()

        function submitResponse(response) {}
        function cancel() {}
        function selectIdentity(index) { selectedIdentityIndex = index }
        function setDialogWindow(windowObject) {}
    }

    Authentication.AuthenticationDialog {
        id: dialog
        backend: previewBackend
    }

    Timer {
        interval: harness.snapshotPath === "" ? 100 : 800
        running: true
        onTriggered: {
            if (harness.snapshotPath === "") {
                console.warn("MEO_AUTHENTICATION_DIALOG_OK")
                Qt.quit()
                return
            }
            dialog.contentItem.grabToImage(function(result) {
                if (!result.saveToFile(harness.snapshotPath))
                    console.error("Unable to save authentication dialog snapshot")
                Qt.quit()
            })
        }
    }
}
