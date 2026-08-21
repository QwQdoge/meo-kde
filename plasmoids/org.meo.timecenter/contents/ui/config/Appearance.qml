import QtQuick
import QtQuick.Controls
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_textScalePercent: textScale.value
    property alias cfg_showDate: showDate.checked
    property alias cfg_showNotifications: showNotifications.checked
    property alias cfg_use24HourClock: use24HourClock.checked

    Kirigami.FormLayout {
        SpinBox {
            id: textScale
            from: 75
            to: 150
            stepSize: 5
            editable: true
            Kirigami.FormData.label: i18n("Text size:")
            textFromValue: function(value) { return i18n("%1%", value) }
        }

        CheckBox {
            id: showDate
            text: i18n("Show date")
        }
        CheckBox {
            id: showNotifications
            text: i18n("Show notifications")
        }
        CheckBox {
            id: use24HourClock
            text: i18n("Use 24-hour clock")
        }
    }
}
