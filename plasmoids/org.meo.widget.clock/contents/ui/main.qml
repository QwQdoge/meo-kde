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

    // Googlebook/Android home widgets are resized in-place. Keep the adapter
    // genuinely usable down to a compact cell instead of advertising SizeSmall
    // while enforcing the old 240 x 176 minimum.
    Layout.minimumWidth: 144 * MeoTheme.globalScale
    Layout.minimumHeight: 120 * MeoTheme.globalScale
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
            id: widget
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

            Loader {
                anchors.fill: parent
                sourceComponent: widget.currentColumns <= 1 || widget.currentRows <= 1
                                 ? compactClock
                                 : widget.wideLayout ? wideClock : stackedClock
            }
        }
    }

    Component {
        id: compactClock

        Item {
            MeoAmbientClock {
                anchors.centerIn: parent
                width: parent.width
                dateTime: root.currentDateTime
                showDate: false
            }
        }
    }

    Component {
        id: wideClock

        RowLayout {
            spacing: MeoTheme.space16

            MeoAmbientClock {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                dateTime: root.currentDateTime
                showDate: true
            }
            MeoWeatherStatus {
                Layout.alignment: Qt.AlignVCenter
                available: MeoSystem.Weather.available
                stale: MeoSystem.Weather.stale
                temperatureText: MeoSystem.Weather.temperatureText
                condition: MeoSystem.Weather.condition
                iconName: MeoSystem.Weather.iconName
                showLocation: false
            }
        }
    }

    Component {
        id: stackedClock

        ColumnLayout {
            spacing: MeoTheme.space8

            MeoAmbientClock {
                Layout.fillWidth: true
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
