import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import MeoKDE 1.0

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
        MeoSpinBox {
            id: textScale
            from: 75
            to: 150
            stepSize: 5
            editable: true
            Kirigami.FormData.label: MeoI18n.translator.i18n("Text size:")
            textFromValue: function(value) { return MeoI18n.translator.i18n("%1%", value) }
        }

        MeoCheckbox {
            id: showNetwork
            text: MeoI18n.translator.i18n("Show network")
        }
        MeoExposedDropdown {
            id: density
            Kirigami.FormData.label: MeoI18n.translator.i18n("Density:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Compact"), value: "compact" }, { text: MeoI18n.translator.i18n("Comfortable"), value: "comfortable" }]
        }
        MeoExposedDropdown {
            id: surfaceStyle
            Kirigami.FormData.label: MeoI18n.translator.i18n("Surface:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Follow theme"), value: "theme" }, { text: MeoI18n.translator.i18n("Flat"), value: "flat" }, { text: MeoI18n.translator.i18n("Tonal"), value: "tonal" }, { text: MeoI18n.translator.i18n("Translucent"), value: "translucent" }]
        }
        MeoSpinBox { id: surfaceOpacity; from: 70; to: 100; stepSize: 5; Kirigami.FormData.label: MeoI18n.translator.i18n("Surface opacity:"); textFromValue: function(value) { return MeoI18n.translator.i18n("%1%", value) } }
        MeoExposedDropdown {
            id: motionProfile
            Kirigami.FormData.label: MeoI18n.translator.i18n("Motion:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Calm"), value: "calm" }, { text: MeoI18n.translator.i18n("Pixel"), value: "pixel" }, { text: MeoI18n.translator.i18n("Playful"), value: "playful" }]
        }
        MeoCheckbox { id: showUnreadBadge; text: MeoI18n.translator.i18n("Show unread badge") }
        MeoCheckbox { id: showJobs; text: MeoI18n.translator.i18n("Show background tasks") }
        MeoCheckbox {
            id: showBluetooth
            text: MeoI18n.translator.i18n("Show Bluetooth")
        }
        MeoCheckbox {
            id: showVolume
            text: MeoI18n.translator.i18n("Show volume")
        }

        MeoExposedDropdown {
            id: batteryDisplay
            Layout.fillWidth: true
            Kirigami.FormData.label: MeoI18n.translator.i18n("Battery:")
            model: [
                MeoI18n.translator.i18n("Hidden"),
                MeoI18n.translator.i18n("Icon only"),
                MeoI18n.translator.i18n("Icon and percentage"),
                MeoI18n.translator.i18n("Detailed state")
            ]
        }

        MeoCheckbox {
            id: showDate
            text: MeoI18n.translator.i18n("Show date")
        }
        MeoCheckbox {
            id: showNotifications
            text: MeoI18n.translator.i18n("Show notifications")
        }
        MeoCheckbox {
            id: use24HourClock
            text: MeoI18n.translator.i18n("Use 24-hour clock")
        }
    }
}
