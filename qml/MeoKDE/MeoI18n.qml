pragma Singleton

import QtQml 2.15
import org.kde.ki18n 1.0

// Keep MeoKDE's user-facing copy in one KDE translation domain.  KI18nContext
// follows the desktop language and also invalidates QML bindings when that
// language changes; it intentionally has no per-account or per-applet setting.
QtObject {
    readonly property KI18nContext translator: KI18nContext {
        translationDomain: "meo-desktop"
    }
}
