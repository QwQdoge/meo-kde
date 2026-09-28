pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami
import Meo.System 1.0 as MeoSystem
import MeoUI 1.0

QtObject {
    id: root

    // KDE/Plasma remains the source of the active accent and mode. Material
    // roles are then generated in native code with HCT/CAM16 SchemeTonalSpot;
    // do not recreate them by blending RGB values in QML.
    property color accentColor: Kirigami.Theme.highlightColor
    property color backgroundColor: Kirigami.Theme.backgroundColor
    property font systemFont: Kirigami.Theme.defaultFont
    property int platformShortDuration: Kirigami.Units.shortDuration
    readonly property bool darkMode: luminance(backgroundColor) < 0.48
    // Exposed for applications that need to prove the shared color table was
    // installed before presenting their first system-facing screen.
    readonly property bool ready: MeoTheme.colorSchemeMode === "dynamic"
                                  && MeoTheme.dynamicColorsAvailable
                                  && MeoTheme.hasCompleteColorScheme(MeoTheme.dynamicColorScheme)
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

    function materialProvider() {
        // Development/offscreen consumers can load the QML module before its
        // optional native plugin is present. Never call an unresolved
        // singleton and never synthesize a partial RGB palette as fallback.
        return typeof MeoSystem.MaterialColors === "undefined"
                ? null : MeoSystem.MaterialColors
    }

    function scheme(provider) {
        // The native provider owns the applied Meo seed/source. Consumers must
        // not regenerate the scheme from Kirigami's accent because wallpaper
        // and manual dynamic-color sources can intentionally differ from it.
        return provider ? provider.currentScheme(darkMode) : null
    }

    function sync() {
        MeoTheme.isDarkMode = darkMode
        // Meo Desktop intentionally uses the M3 Expressive spatial scheme.
        // Effect motion remains critically damped; only scale, position and
        // bounds receive the controlled spring overshoot.
        MeoTheme.isExpressive = true
        MeoTheme.fontFamily = systemFont.family
        MeoTheme.fontScale = Math.max(0.85, Math.min(1.5, systemFontPixels / 14))
        // Kirigami already applies KDE's AnimationDurationFactor. Bridge that
        // platform preference into shared MeoUI motion tokens instead of
        // maintaining a second, contradictory animation switch.
        MeoTheme.reduceMotion = platformShortDuration <= 0
        MeoTheme.isBouncy = !MeoTheme.reduceMotion
        MeoTheme.motionScale = MeoTheme.reduceMotion
                ? 0 : Math.max(0.25, Math.min(4, platformShortDuration / 100))
        const provider = materialProvider()
        const generated = scheme(provider)
        if (generated && provider)
            MeoTheme.applyDynamicColorScheme(generated, provider.sourceId())
        else
            MeoTheme.clearDynamicColorScheme()
    }

    onAccentColorChanged: sync()
    onBackgroundColorChanged: sync()
    onSystemFontChanged: sync()
    onPlatformShortDurationChanged: sync()

    // The Material provider can change its Meo seed/source without KDE's
    // Kirigami highlight color changing. Keep every MeoShellTheme consumer
    // live in that case instead of requiring each application to reconnect.
    Connections {
        target: root.materialProvider()
        ignoreUnknownSignals: true

        function onSchemeChanged() {
            root.sync()
        }
    }

    Component.onCompleted: sync()
}
