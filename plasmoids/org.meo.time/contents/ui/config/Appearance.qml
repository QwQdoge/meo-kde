import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
KCM.SimpleKCM { property alias cfg_clockFormat: clock.currentValue; property alias cfg_showDate: date.checked; property alias cfg_showSeconds: seconds.checked; property alias cfg_showWeekNumbers: weeks.checked; property alias cfg_showSecondaryCalendar: secondary.checked; Kirigami.FormLayout { MeoExposedDropdown { id: clock; Kirigami.FormData.label: i18n("Clock:"); textRole:"text"; valueRole:"value"; model:[{text:i18n("System default"),value:"system"},{text:i18n("24-hour"),value:"24h"},{text:i18n("12-hour"),value:"12h"}] } MeoCheckbox { id: date; text:i18n("Show date") } MeoCheckbox { id: seconds; text:i18n("Show seconds") } MeoCheckbox { id: weeks; text:i18n("Show week numbers") } MeoCheckbox { id: secondary; text:i18n("Show secondary calendar") } } }
