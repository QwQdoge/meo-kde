import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import MeoKDE 1.0

KCM.SimpleKCM {
    property alias cfg_showLauncherButton: showLauncherButton.checked
    property alias cfg_filterTasksByVirtualDesktop: filterTasksByVirtualDesktop.checked
    property alias cfg_showRunningIndicators: showRunningIndicators.checked
    property alias cfg_showTooltips: showTooltips.checked
    property alias cfg_launcherDefaultPage: launcherDefaultPage.currentValue
    property alias cfg_launcherWidth: launcherWidth.currentValue
    property alias cfg_launcherShowFavorites: launcherShowFavorites.checked
    property alias cfg_launcherShowRecents: launcherShowRecents.checked

    Kirigami.FormLayout {
        MeoCheckbox {
            id: showLauncherButton
            text: MeoI18n.translator.i18n("Show Launcher button")
        }
        MeoCheckbox {
            id: filterTasksByVirtualDesktop
            text: MeoI18n.translator.i18n("Only show apps on the current virtual desktop")
        }
        MeoCheckbox {
            id: showRunningIndicators
            text: MeoI18n.translator.i18n("Show running indicators")
        }
        MeoCheckbox {
            id: showTooltips
            text: MeoI18n.translator.i18n("Show app tooltips")
        }

        MeoExposedDropdown {
            id: launcherDefaultPage
            Kirigami.FormData.label: MeoI18n.translator.i18n("Launcher opens to:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: MeoI18n.translator.i18n("Home"), value: "home" },
                { text: MeoI18n.translator.i18n("All apps"), value: "apps" }
            ]
        }
        MeoExposedDropdown {
            id: launcherWidth
            Kirigami.FormData.label: MeoI18n.translator.i18n("Launcher width:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: MeoI18n.translator.i18n("Compact"), value: "compact" },
                { text: MeoI18n.translator.i18n("Standard"), value: "standard" },
                { text: MeoI18n.translator.i18n("Wide"), value: "wide" }
            ]
        }
        MeoCheckbox {
            id: launcherShowFavorites
            text: MeoI18n.translator.i18n("Show pinned apps on Home")
        }
        MeoCheckbox {
            id: launcherShowRecents
            text: MeoI18n.translator.i18n("Show recent items on Home")
        }
    }
}
