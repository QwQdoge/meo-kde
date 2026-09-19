import QtQuick
import QtQuick.Controls
import MeoUI 1.0
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import MeoKDE 1.0
KCM.SimpleKCM { property alias cfg_clockFormat: clock.currentValue; property alias cfg_showDate: date.checked; property alias cfg_showSeconds: seconds.checked; property alias cfg_showWeekNumbers: weeks.checked; property alias cfg_showSecondaryCalendar: secondary.checked; Kirigami.FormLayout { MeoExposedDropdown { id: clock; Kirigami.FormData.label: MeoI18n.translator.i18n("Clock:"); textRole:"text"; valueRole:"value"; model:[{text:MeoI18n.translator.i18n("System default"),value:"system"},{text:MeoI18n.translator.i18n("24-hour"),value:"24h"},{text:MeoI18n.translator.i18n("12-hour"),value:"12h"}] } MeoCheckbox { id: date; text:MeoI18n.translator.i18n("Show date") } MeoCheckbox { id: seconds; text:MeoI18n.translator.i18n("Show seconds") } MeoCheckbox { id: weeks; text:MeoI18n.translator.i18n("Show week numbers") } MeoCheckbox { id: secondary; text:MeoI18n.translator.i18n("Show secondary calendar") } } }
