pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami
import Meo.System 1.0
import MeoUI 1.0

QtObject {
    id: root

    // KDE/Plasma remains the source of the active accent and mode. Material
    // roles are then generated in native code with HCT/CAM16 SchemeTonalSpot;
    // do not recreate them by blending RGB values in QML.
    property color accentColor: Kirigami.Theme.highlightColor
    property color backgroundColor: Kirigami.Theme.backgroundColor
    property font systemFont: Kirigami.Theme.defaultFont
    readonly property bool darkMode: luminance(backgroundColor) < 0.48
    readonly property real systemFontPixels: systemFont.pixelSize > 0
                                              ? systemFont.pixelSize
                                              : Math.max(1, systemFont.pointSize * 96 / 72)

    function luminance(color) {
        function linear(channel) {
            return channel <= 0.04045 ? channel / 12.92
                                      : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g)
                + 0.0722 * linear(color.b)
    }

    function scheme() {
        return MaterialColors.schemeFor(accentColor, darkMode)
    }

    function sync() {
        MeoTheme.isDarkMode = darkMode
        MeoTheme.fontFamily = systemFont.family
        MeoTheme.fontScale = Math.max(0.85, Math.min(1.5, systemFontPixels / 14))
        const generated = scheme()
        if (generated && generated.primary && generated.onSurface)
            MeoTheme.applyDynamicColorScheme(generated)
        else
            MeoTheme.clearDynamicColorScheme()
    }

    onAccentColorChanged: sync()
    onBackgroundColorChanged: sync()
    onSystemFontChanged: sync()
    Component.onCompleted: sync()
}
