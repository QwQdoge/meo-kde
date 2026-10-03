import QtQuick
import MeoUI 1.0

// The host calls DecideRequest with this immutable request ID and fingerprint.
// Closing the card must be treated exactly like choosing Reject.
MeoDialog {
    id: root
    required property var request

    signal decision(string requestId, string fingerprint, bool approve)

    title: String(request.title || "Confirm action")
    message: qsTr("Target: %1\n%2").arg(String(request.target || ""))
             .arg(String(request.impact || qsTr("This action cannot be undone.")))
    icon: "warning"
    confirmText: qsTr("Agree")
    cancelText: qsTr("Reject")

    onConfirmed: decision(String(request.requestId), String(request.fingerprint), true)
    onCancelled: decision(String(request.requestId), String(request.fingerprint), false)
    onDismissed: decision(String(request.requestId), String(request.fingerprint), false)
}
