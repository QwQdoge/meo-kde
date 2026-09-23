import QtQuick
import org.kde.plasma.configuration
import MeoKDE 1.0

ConfigModel {
    ConfigCategory {
        name: MeoI18n.translator.i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/Appearance.qml"
    }
}
