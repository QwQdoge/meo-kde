import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import MeoUI 1.0
import MeoKDE 1.0

KCM.SimpleKCM {
    property alias cfg_scalePercent: scalePercent.value
    property alias cfg_surfaceStyle: surfaceStyle.currentValue
    property alias cfg_surfaceOpacityPercent: surfaceOpacity.value
    property alias cfg_showLauncher: showLauncher.checked
    property alias cfg_showRunningIndicators: showRunningIndicators.checked
    property alias cfg_showTooltips: showTooltips.checked
    property alias cfg_launcherShowRecent: launcherShowRecent.checked
    property alias cfg_launcherColumns: launcherColumns.value
    property alias cfg_launcherScalePercent: launcherScale.value

    Kirigami.FormLayout {
        MeoSpinBox {
            id: scalePercent
            from: 80
            to: 130
            stepSize: 5
            editable: true
            Kirigami.FormData.label: MeoI18n.translator.i18n("Shelf size:")
            textFromValue: function(value) { return MeoI18n.translator.i18n("%1%", value) }
        }

        MeoExposedDropdown {
            id: surfaceStyle
            Kirigami.FormData.label: MeoI18n.translator.i18n("Surface:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: MeoI18n.translator.i18n("Follow theme"), value: "theme" },
                { text: MeoI18n.translator.i18n("Flat"), value: "flat" },
                { text: MeoI18n.translator.i18n("Tonal"), value: "tonal" },
                { text: MeoI18n.translator.i18n("Translucent"), value: "translucent" }
            ]
        }

        MeoSpinBox {
            id: surfaceOpacity
            from: 70
            to: 100
            stepSize: 5
            Kirigami.FormData.label: MeoI18n.translator.i18n("Surface opacity:")
            textFromValue: function(value) { return MeoI18n.translator.i18n("%1%", value) }
        }

        MeoCheckbox { id: showLauncher; text: MeoI18n.translator.i18n("Show launcher button") }
        MeoCheckbox { id: showRunningIndicators; text: MeoI18n.translator.i18n("Show running indicators") }
        MeoCheckbox { id: showTooltips; text: MeoI18n.translator.i18n("Show tooltips") }
        MeoCheckbox { id: launcherShowRecent; text: MeoI18n.translator.i18n("Show recent apps and documents") }

        MeoSpinBox {
            id: launcherColumns
            from: 4
            to: 7
            stepSize: 1
            Kirigami.FormData.label: MeoI18n.translator.i18n("Launcher columns:")
        }

        MeoSpinBox {
            id: launcherScale
            from: 80
            to: 130
            stepSize: 5
            Kirigami.FormData.label: MeoI18n.translator.i18n("Launcher size:")
            textFromValue: function(value) { return MeoI18n.translator.i18n("%1%", value) }
        }
    }
}
