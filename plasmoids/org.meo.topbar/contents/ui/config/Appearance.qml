import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root

    property alias cfg_textScalePercent: textScale.value
    property alias cfg_showNetwork: showNetwork.checked
    property alias cfg_showBluetooth: showBluetooth.checked
    property alias cfg_showVolume: showVolume.checked
    property alias cfg_batteryDisplay: batteryDisplay.currentIndex
    property alias cfg_showDate: showDate.checked
    property alias cfg_showNotifications: showNotifications.checked
    property alias cfg_use24HourClock: use24HourClock.checked
    property alias cfg_density: density.currentValue
    property alias cfg_surfaceStyle: surfaceStyle.currentValue
    property alias cfg_surfaceOpacityPercent: surfaceOpacity.value
    property alias cfg_motionProfile: motionProfile.currentValue
    property alias cfg_showUnreadBadge: showUnreadBadge.checked
    property alias cfg_showJobs: showJobs.checked

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
            id: showNetwork
            text: i18n("Show network")
        }
        ComboBox {
            id: density
            Kirigami.FormData.label: i18n("Density:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("Compact"), value: "compact" }, { text: i18n("Comfortable"), value: "comfortable" }]
        }
        ComboBox {
            id: surfaceStyle
            Kirigami.FormData.label: i18n("Surface:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("Follow theme"), value: "theme" }, { text: i18n("Flat"), value: "flat" }, { text: i18n("Tonal"), value: "tonal" }, { text: i18n("Translucent"), value: "translucent" }]
        }
        SpinBox { id: surfaceOpacity; from: 70; to: 100; stepSize: 5; Kirigami.FormData.label: i18n("Surface opacity:"); textFromValue: function(value) { return i18n("%1%", value) } }
        ComboBox {
            id: motionProfile
            Kirigami.FormData.label: i18n("Motion:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("Calm"), value: "calm" }, { text: i18n("Pixel"), value: "pixel" }, { text: i18n("Playful"), value: "playful" }]
        }
        CheckBox { id: showUnreadBadge; text: i18n("Show unread badge") }
        CheckBox { id: showJobs; text: i18n("Show background tasks") }
        CheckBox {
            id: showBluetooth
            text: i18n("Show Bluetooth")
        }
        CheckBox {
            id: showVolume
            text: i18n("Show volume")
        }

        ComboBox {
            id: batteryDisplay
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Battery:")
            model: [
                i18n("Hidden"),
                i18n("Icon only"),
                i18n("Icon and percentage"),
                i18n("Detailed state")
            ]
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
