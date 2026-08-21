import QtQuick
import QtQuick.Controls
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_taskLimit: taskLimit.value

    Kirigami.FormLayout {
        SpinBox {
            id: taskLimit
            from: 1
            to: 12
            stepSize: 1
            editable: true
            Kirigami.FormData.label: i18n("Open application icons:")
        }
    }
}
