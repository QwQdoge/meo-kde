import QtQuick
import QtQuick.Window
import MeoUI 1.0
import MeoKDE 1.0

Window {
    width: 1
    height: 1
    visible: true

    MeoText {
        id: typeProbe
        typeRole: "body"
        typeSize: "medium"
    }

    Component.onCompleted: {
        MeoShellTheme.sync()
        checkTimer.start()
    }

    Timer {
        id: checkTimer
        interval: 0
        onTriggered: {
            if (MeoTheme.fontFamily.length === 0)
                throw new Error("system font family did not reach MeoUI")
            if (MeoTheme.fontScale < 0.85 || MeoTheme.fontScale > 1.5)
                throw new Error("font scale is outside the supported range")
            if (!MeoTheme.dynamicColorsAvailable)
                throw new Error("system palette did not reach MeoUI")
            if (ShellMetrics.radiusControl !== MeoTheme.shapeMedium)
                throw new Error("shell control radius bypasses MeoUI shape tokens")
            if (ShellMetrics.radiusPopup !== MeoTheme.shapeExtraLarge)
                throw new Error("shell popup radius bypasses MeoUI shape tokens")
            const expectedTypeSize = MeoTheme.bodyMediumUi.size
                                     * MeoTheme.globalScale * MeoTheme.fontScale
            if (Math.abs(typeProbe.font.pixelSize - expectedTypeSize) > 1)
                throw new Error("MeoText does not consume the dynamic font scale")

            console.warn("MEO_THEME_RUNTIME_OK",
                         "font=" + MeoTheme.fontFamily,
                         "fontScale=" + MeoTheme.fontScale,
                         "dark=" + MeoTheme.isDarkMode,
                         "primary=" + MeoTheme.primary)
            Qt.quit()
        }
    }
}
