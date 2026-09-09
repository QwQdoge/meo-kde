import QtQuick
import MeoKDE 1.0
StatusCenterView {
    id: root

    property var notifications: null
    property date currentDateTime: new Date()
    property bool use24HourClock: true // compatibility for existing callers
    centerMode: "timeCalendarNotifications"
    clockFormat: root.use24HourClock ? "24h" : "12h"
}
