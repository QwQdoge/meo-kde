import QtQuick
import MeoUI 1.0

MeoText {
    property string sectionText: ""
    text: sectionText
    typeRole: "label"
    typeSize: "medium"
    emphasized: true
    color: MeoTheme.onSurface
}
