pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami
import MeoUI 1.0

QtObject {
    id: root

    // Plasma can derive its accent from the wallpaper. This bridge turns that
    // live system palette into the complete role object consumed by MeoUI.
    property color accentColor: Kirigami.Theme.highlightColor
    property color backgroundColor: Kirigami.Theme.backgroundColor
    property color textColor: Kirigami.Theme.textColor
    property color disabledTextColor: Kirigami.Theme.disabledTextColor
    readonly property bool darkMode: luminance(backgroundColor) < 0.48

    function luminance(color) {
        function linear(channel) {
            return channel <= 0.04045 ? channel / 12.92
                                      : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g)
                + 0.0722 * linear(color.b)
    }

    function mix(first, second, amount) {
        const t = Math.max(0, Math.min(1, amount))
        return Qt.rgba(first.r * (1 - t) + second.r * t,
                       first.g * (1 - t) + second.g * t,
                       first.b * (1 - t) + second.b * t,
                       first.a * (1 - t) + second.a * t)
    }

    function scheme() {
        const base = backgroundColor
        const ink = textColor
        const accent = accentColor
        const white = Qt.rgba(1, 1, 1, 1)
        const black = Qt.rgba(0, 0, 0, 1)
        const onAccent = luminance(accent) > 0.48 ? black : white
        const surfaceStep = darkMode ? white : black
        const primaryContainer = mix(base, accent, darkMode ? 0.34 : 0.22)
        const secondary = mix(accent, ink, darkMode ? 0.36 : 0.48)
        const tertiary = mix(accent, darkMode ? Qt.rgba(1, 0.64, 0.72, 1)
                                              : Qt.rgba(0.52, 0.20, 0.30, 1), 0.34)

        return {
            "primary": accent,
            "onPrimary": onAccent,
            "primaryContainer": primaryContainer,
            "onPrimaryContainer": ink,
            "secondary": secondary,
            "onSecondary": luminance(secondary) > 0.48 ? black : white,
            "secondaryContainer": mix(base, secondary, darkMode ? 0.28 : 0.16),
            "onSecondaryContainer": ink,
            "tertiary": tertiary,
            "onTertiary": luminance(tertiary) > 0.48 ? black : white,
            "tertiaryContainer": mix(base, tertiary, darkMode ? 0.30 : 0.17),
            "onTertiaryContainer": ink,
            "error": darkMode ? "#ffb4ab" : "#ba1a1a",
            "onError": darkMode ? "#690005" : "#ffffff",
            "errorContainer": darkMode ? "#93000a" : "#ffdad6",
            "onErrorContainer": darkMode ? "#ffdad6" : "#410002",
            "background": base,
            "onBackground": ink,
            "surface": base,
            "onSurface": ink,
            "surfaceVariant": mix(base, accent, darkMode ? 0.18 : 0.10),
            "onSurfaceVariant": mix(ink, base, 0.24),
            "outline": mix(ink, base, 0.46),
            "outlineVariant": mix(ink, base, darkMode ? 0.70 : 0.76),
            "surfaceContainerLowest": mix(base, surfaceStep, darkMode ? 0.05 : 0.00),
            "surfaceContainerLow": mix(base, surfaceStep, darkMode ? 0.08 : 0.025),
            "surfaceContainer": mix(base, surfaceStep, darkMode ? 0.11 : 0.045),
            "surfaceContainerHigh": mix(base, surfaceStep, darkMode ? 0.15 : 0.07),
            "surfaceContainerHighest": mix(base, surfaceStep, darkMode ? 0.20 : 0.10),
            "inverseSurface": ink,
            "onInverseSurface": base
        }
    }

    function sync() {
        MeoTheme.isDarkMode = darkMode
        MeoTheme.fontFamily = "Roboto"
        MeoTheme.fontFamilyBrand = "Comfortaa"
        MeoTheme.applyDynamicColorScheme(scheme())
    }

    onAccentColorChanged: sync()
    onBackgroundColorChanged: sync()
    onTextColorChanged: sync()
    Component.onCompleted: sync()
}

