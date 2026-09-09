import QtQuick
import QtQuick.Controls
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_textScalePercent: textScale.value
    property alias cfg_showDate: showDate.checked
    property alias cfg_showNotifications: showNotifications.checked
    property alias cfg_use24HourClock: use24HourClock.checked
    property alias cfg_density: density.currentValue
    property alias cfg_surfaceStyle: surfaceStyle.currentValue
    property alias cfg_surfaceOpacityPercent: surfaceOpacity.value
    property alias cfg_motionProfile: motionProfile.currentValue
    property alias cfg_showUnreadBadge: showUnreadBadge.checked
    property alias cfg_showJobs: showJobs.checked
    property alias cfg_clockFormat: clockFormat.currentValue
    property alias cfg_showSeconds: showSeconds.checked
    property alias cfg_popupLayout: popupLayout.currentValue
    property alias cfg_defaultPage: defaultPage.currentValue
    property alias cfg_showWeekNumbers: showWeekNumbers.checked
    property alias cfg_showSecondaryCalendar: showSecondaryCalendar.checked

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

        ComboBox {
            id: density
            Kirigami.FormData.label: i18n("Density:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("Compact"), value: "compact" }, { text: i18n("Comfortable"), value: "comfortable" }]
        }
        ComboBox {
            id: clockFormat
            Kirigami.FormData.label: i18n("Clock:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("System default"), value: "system" }, { text: i18n("24-hour"), value: "24h" }, { text: i18n("12-hour"), value: "12h" }]
        }
        CheckBox { id: showSeconds; text: i18n("Show seconds") }
        CheckBox { id: showUnreadBadge; text: i18n("Show unread badge") }
        CheckBox { id: showJobs; text: i18n("Show background tasks") }
        ComboBox {
            id: popupLayout
            Kirigami.FormData.label: i18n("Popup layout:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("Standard"), value: "standard" }, { text: i18n("Wide"), value: "wide" }]
        }
        ComboBox {
            id: defaultPage
            Kirigami.FormData.label: i18n("Default content:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("Notifications"), value: "notifications" }, { text: i18n("Calendar"), value: "calendar" }]
        }
        CheckBox { id: showWeekNumbers; text: i18n("Show week numbers") }
        CheckBox { id: showSecondaryCalendar; text: i18n("Show secondary calendar") }
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
