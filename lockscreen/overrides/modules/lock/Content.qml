import QtQuick
import QtQuick.Layouts
import qs.components

RowLayout {
    id: root

    required property var lock

    spacing: Tokens.spacing.largeIncreased * 2

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        Loader {
            Layout.fillWidth: true
            active: MeoSessionEntry.weatherEnabled && MeoWeatherCache.available
            asynchronous: true

            sourceComponent: WeatherInfo {
                rootHeight: root.height
            }
        }

        Fetch {
            Layout.fillWidth: true
            rootHeight: root.height
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: MeoSessionEntry.mediaEnabled
            asynchronous: true

            sourceComponent: Media {
                lock: root.lock
            }
        }
    }

    Center {
        lock: root.lock
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        Resources {
            Layout.fillWidth: true
        }

        MeoNotificationPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            lock: root.lock
        }
    }
}
