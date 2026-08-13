pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami
import MeoUI 1.0

QtObject {
    id: root

    // Plasma can derive its accent from the wallpaper. This bridge turns that
    // live system palette into the complete role object consumed by MeoUI.
    property color accentColor: Kirigami.Theme.highlightColor
    property color contentOnAccentColor: Kirigami.Theme.highlightedTextColor
    property color backgroundColor: Kirigami.Theme.backgroundColor
    property color textColor: Kirigami.Theme.textColor
    property color disabledTextColor: Kirigami.Theme.disabledTextColor
    property color linkColor: Kirigami.Theme.linkColor
    property color positiveColor: Kirigami.Theme.positiveTextColor
    property color negativeColor: Kirigami.Theme.negativeTextColor
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
        const onAccent = contentOnAccentColor
        const surfaceStep = darkMode ? Qt.rgba(1, 1, 1, 1)
                                     : Qt.rgba(0, 0, 0, 1)
        const primaryContainer = mix(base, accent, darkMode ? 0.34 : 0.22)
        const secondary = linkColor
        const tertiary = positiveColor
        const error = negativeColor

        return {
            "primary": accent,
            "onPrimary": onAccent,
            "primaryContainer": primaryContainer,
            "onPrimaryContainer": ink,
            "secondary": secondary,
            "onSecondary": contentColorFor(secondary),
            "secondaryContainer": mix(base, secondary, darkMode ? 0.28 : 0.16),
            "onSecondaryContainer": ink,
            "tertiary": tertiary,
            "onTertiary": contentColorFor(tertiary),
            "tertiaryContainer": mix(base, tertiary, darkMode ? 0.30 : 0.17),
            "onTertiaryContainer": ink,
            "error": error,
            "onError": contentColorFor(error),
            "errorContainer": mix(base, error, darkMode ? 0.34 : 0.18),
            "onErrorContainer": ink,
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

    function contentColorFor(color) {
        return luminance(color) > 0.48 ? Qt.rgba(0, 0, 0, 1)
                                       : Qt.rgba(1, 1, 1, 1)
    }

    function sync() {
        MeoTheme.isDarkMode = darkMode
        MeoTheme.fontFamily = systemFont.family
        MeoTheme.fontScale = Math.max(0.85, Math.min(1.5, systemFontPixels / 14))
        MeoTheme.applyDynamicColorScheme(scheme())
    }

    onAccentColorChanged: sync()
    onBackgroundColorChanged: sync()
    onTextColorChanged: sync()
    onContentOnAccentColorChanged: sync()
    onLinkColorChanged: sync()
    onPositiveColorChanged: sync()
    onNegativeColorChanged: sync()
    onSystemFontChanged: sync()
    Component.onCompleted: sync()
}
