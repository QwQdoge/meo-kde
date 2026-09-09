import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root
    readonly property bool use24Hour: Plasmoid.configuration.clockFormat === "24h"
                                      || (Plasmoid.configuration.clockFormat === "system"
                                          && Qt.locale().timeFormat(Locale.ShortFormat).indexOf("AP") < 0)
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: qsTr("Meo Time")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: compactRepresentation
    Layout.minimumWidth: compactRepresentationItem ? compactRepresentationItem.implicitWidth : 64 * MeoTheme.globalScale; Layout.preferredWidth: Layout.minimumWidth; Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight; Layout.preferredHeight: Layout.minimumHeight; Layout.maximumHeight: Layout.minimumHeight
    PlasmaClock.Clock { id: clock; trackSeconds: Plasmoid.configuration.showSeconds }
    compactRepresentation: QQC2.AbstractButton {
        implicitWidth: label.implicitWidth + 8 * MeoTheme.globalScale; implicitHeight: 28 * MeoTheme.globalScale
        Accessible.name: qsTr("Time and calendar")
        onClicked: root.expanded = !root.expanded
        background: MeoShape { type:"pill"; radius:height/2; color: parent.hovered || parent.down || root.expanded ? MeoTheme.surfaceContainerHighest : "transparent" }
        contentItem: RowLayout { id: label; spacing: MeoTheme.space4; MeoText { text: Qt.formatTime(clock.dateTime, root.use24Hour ? (Plasmoid.configuration.showSeconds ? "hh:mm:ss" : "hh:mm") : (Plasmoid.configuration.showSeconds ? "h:mm:ss AP" : "h:mm AP")); typeRole:"label"; typeSize:"medium"; emphasized:true } MeoText { visible: Plasmoid.configuration.showDate; text:Qt.formatDate(clock.dateTime, "MMM d"); typeRole:"label"; typeSize:"small" } }
    }
    fullRepresentation: StatusCenterView { currentDateTime: clock.dateTime; centerMode:"timeCalendar"; clockFormat: Plasmoid.configuration.clockFormat; showSeconds: Plasmoid.configuration.showSeconds; showDate: Plasmoid.configuration.showDate; showWeekNumbers: Plasmoid.configuration.showWeekNumbers; showSecondaryCalendar: Plasmoid.configuration.showSecondaryCalendar }
}
