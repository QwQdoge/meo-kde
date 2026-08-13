# Qt Quick and Kirigami integration

## Qt Widgets

Qt Widgets are painted by the `Meo` QStyle plugin. It uses `QPainter`, public
QStyle APIs, the current `QPalette`, and MeoUI's shared C++ design tokens.

## Meo Qt Quick applications

Meo applications should import `MeoUI 1.0` and use the existing components
directly. They do not route through QStyle or instantiate QWidget controls.

## Third-party Qt Quick and Kirigami applications

KDE's Qt Quick Controls desktop integration may inherit palette, font, and
some metric behavior from the desktop. It is not a complete QStyle renderer.
Meo does not inject QML, rewrite Kirigami pages, or claim to transform every
third-party Qt Quick application. Applications requiring Meo controls should
adopt MeoUI explicitly.

## Non-Qt toolkits

GTK, Electron, and web content are out of scope for QStyle. They can share
icons, system palette, decoration, and future toolkit-specific themes, but are
never CSS- or preload-injected by Meo Desktop.
