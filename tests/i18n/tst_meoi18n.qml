import QtQuick 2.15
import QtTest 1.0
import MeoKDE 1.0

TestCase {
    name: "MeoI18n"

    function test_uses_the_desktop_language_catalog() {
        compare(MeoI18n.translator.i18n("Meo Quick Settings"), "Meo 快速设置")
        compare(MeoI18n.translator.i18n("Dismiss notification"), "关闭通知")
    }
}
