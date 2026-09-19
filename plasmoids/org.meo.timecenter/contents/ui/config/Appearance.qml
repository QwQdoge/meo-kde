import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import MeoKDE 1.0

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
    property alias cfg_showNotificationHistory: notificationHistory.checked
    property alias cfg_notificationView: notificationView.currentValue
    property alias cfg_notificationPreview: notificationPreview.currentValue
    property alias cfg_clockFormat: clockFormat.currentValue
    property alias cfg_showSeconds: showSeconds.checked
    property alias cfg_popupLayout: popupLayout.currentValue
    property alias cfg_defaultPage: defaultPage.currentValue
    property alias cfg_showWeekNumbers: showWeekNumbers.checked
    property alias cfg_showSecondaryCalendar: showSecondaryCalendar.checked

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
            id: showDate
            text: MeoI18n.translator.i18n("Show date")
        }

        MeoExposedDropdown {
            id: density
            Kirigami.FormData.label: MeoI18n.translator.i18n("Density:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Compact"), value: "compact" }, { text: MeoI18n.translator.i18n("Comfortable"), value: "comfortable" }]
        }
        MeoExposedDropdown {
            id: clockFormat
            Kirigami.FormData.label: MeoI18n.translator.i18n("Clock:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("System default"), value: "system" }, { text: MeoI18n.translator.i18n("24-hour"), value: "24h" }, { text: MeoI18n.translator.i18n("12-hour"), value: "12h" }]
        }
        MeoCheckbox { id: showSeconds; text: MeoI18n.translator.i18n("Show seconds") }
        MeoCheckbox { id: showUnreadBadge; text: MeoI18n.translator.i18n("Show unread badge") }
        MeoCheckbox { id: showJobs; text: MeoI18n.translator.i18n("Show background tasks") }
        MeoCheckbox { id: notificationHistory; text: MeoI18n.translator.i18n("Show notification history") }
        MeoExposedDropdown {
            id: notificationView
            Kirigami.FormData.label: MeoI18n.translator.i18n("Notification view:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Cards"), value: "cards" }, { text: MeoI18n.translator.i18n("Compact list"), value: "compact" }]
        }
        MeoExposedDropdown {
            id: notificationPreview
            Kirigami.FormData.label: MeoI18n.translator.i18n("Preview:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Full"), value: "full" }, { text: MeoI18n.translator.i18n("Summary"), value: "summary" }, { text: MeoI18n.translator.i18n("Hidden"), value: "hidden" }]
        }
        MeoExposedDropdown {
            id: popupLayout
            Kirigami.FormData.label: MeoI18n.translator.i18n("Popup layout:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Standard"), value: "standard" }, { text: MeoI18n.translator.i18n("Wide"), value: "wide" }]
        }
        MeoExposedDropdown {
            id: defaultPage
            Kirigami.FormData.label: MeoI18n.translator.i18n("Default content:")
            textRole: "text"; valueRole: "value"
            model: [{ text: MeoI18n.translator.i18n("Notifications"), value: "notifications" }, { text: MeoI18n.translator.i18n("Calendar"), value: "calendar" }]
        }
        MeoCheckbox { id: showWeekNumbers; text: MeoI18n.translator.i18n("Show week numbers") }
        MeoCheckbox { id: showSecondaryCalendar; text: MeoI18n.translator.i18n("Show secondary calendar") }
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
