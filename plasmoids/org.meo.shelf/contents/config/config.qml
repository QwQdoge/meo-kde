import QtQuick
import org.kde.plasma.configuration
import MeoKDE 1.0

ConfigModel {
    ConfigCategory {
        name: MeoI18n.translator.i18n("Shelf & Launcher")
        icon: "preferences-desktop-dock"
        source: "config/Appearance.qml"
    }
}
