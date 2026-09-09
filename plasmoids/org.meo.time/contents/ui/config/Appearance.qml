import QtQuick
import QtQuick.Controls
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
KCM.SimpleKCM { property alias cfg_clockFormat: clock.currentValue; property alias cfg_showDate: date.checked; property alias cfg_showSeconds: seconds.checked; property alias cfg_showWeekNumbers: weeks.checked; property alias cfg_showSecondaryCalendar: secondary.checked; Kirigami.FormLayout { ComboBox { id: clock; Kirigami.FormData.label: i18n("Clock:"); textRole:"text"; valueRole:"value"; model:[{text:i18n("System default"),value:"system"},{text:i18n("24-hour"),value:"24h"},{text:i18n("12-hour"),value:"12h"}] } CheckBox { id: date; text:i18n("Show date") } CheckBox { id: seconds; text:i18n("Show seconds") } CheckBox { id: weeks; text:i18n("Show week numbers") } CheckBox { id: secondary; text:i18n("Show secondary calendar") } } }
