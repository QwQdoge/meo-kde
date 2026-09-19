pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem
import MeoKDE 1.0

PlasmoidItem {
    id: root

    Plasmoid.title: MeoI18n.translator.i18n("Meo Clock")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: fullRepresentation
    property date currentDateTime: new Date()

    Layout.minimumWidth: 240 * MeoTheme.globalScale
    Layout.minimumHeight: 176 * MeoTheme.globalScale
    Layout.preferredWidth: 320 * MeoTheme.globalScale
    Layout.preferredHeight: 224 * MeoTheme.globalScale

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentDateTime = new Date()
    }

    fullRepresentation: Item {
        implicitWidth: 320 * MeoTheme.globalScale
        implicitHeight: 224 * MeoTheme.globalScale

        MeoWidget {
            anchors.fill: parent
            widgetId: "clock"
            preferredSize: MeoWidget.SizeMedium
            supportedSizes: [MeoWidget.SizeSmall, MeoWidget.SizeWide,
                             MeoWidget.SizeMedium, MeoWidget.SizeLarge]
            privacy: MeoWidget.Location
            refreshPolicy: MeoWidget.Periodic
            supportedSurfaces: [MeoWidget.Desktop, MeoWidget.LockScreen]
            accessibleName: Plasmoid.title
            accessibleDescription: MeoI18n.translator.i18n("Date, time, and optional cached weather")

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space16
                spacing: MeoTheme.space8

                MeoAmbientClock {
                    Layout.alignment: Qt.AlignHCenter
                    dateTime: root.currentDateTime
                    showDate: true
                }
                MeoWeatherStatus {
                    Layout.alignment: Qt.AlignHCenter
                    available: MeoSystem.Weather.available
                    stale: MeoSystem.Weather.stale
                    temperatureText: MeoSystem.Weather.temperatureText
                    condition: MeoSystem.Weather.condition
                    iconName: MeoSystem.Weather.iconName
                    showLocation: false
                }
            }
        }
    }
}
