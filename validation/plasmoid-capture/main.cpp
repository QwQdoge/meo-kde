// SPDX-License-Identifier: GPL-2.0-or-later
// Isolated applet rendering probe; never changes the live Plasma containment.
#include <QApplication>
#include <QQuickWindow>
#include <QTimer>
#include <QScreen>
#include <QDebug>
#include <QImage>
#include <Plasma/Containment>
#include <Plasma/PluginLoader>
#include <Plasma/Corona>
#include <KPackage/Package>
#include <KPackage/PackageLoader>
#include <PlasmaQuick/AppletQuickItem>
#include <KPluginMetaData>

class PreviewCorona final : public Plasma::Corona {
public:
    QRect screenGeometry(int) const override { return QGuiApplication::primaryScreen()->geometry(); }
};

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    if (argc < 3) return 2;
    PreviewCorona corona;
    auto shell = KPackage::PackageLoader::self()->loadPackage(QStringLiteral("Plasma/Shell"));
    shell.setPath(QStringLiteral("org.kde.plasma.desktop"));
    corona.setKPackage(shell);
    auto *containment = corona.createContainment(QStringLiteral("empty"));
    if (!containment) return 6;
    containment->setFormFactor(Plasma::Types::Horizontal);
    containment->setLocation(Plasma::Types::TopEdge);
    auto *applet = Plasma::PluginLoader::self()->loadApplet(QString::fromLocal8Bit(argv[1]));
    if (!applet) return 3;
    containment->addApplet(applet);
    auto *item = PlasmaQuick::AppletQuickItem::itemForApplet(applet);
    if (!item) { fprintf(stderr, "Applet load failed: %s\n", qPrintable(applet->launchErrorMessage())); return 4; }
    QQuickWindow window;
    window.setTitle(QStringLiteral("Meo isolated shell preview"));
    window.resize(640, 240);
    window.setColor(QColor("#18243d")); // Explicit preview-only backdrop.
    item->setParentItem(window.contentItem());
    item->setPosition(QPointF(24, 24));
    item->setSize(QSizeF(160, 48));
    window.show();
    QTimer::singleShot(1200, &app, [&] {
        if (argc > 3 && QByteArray(argv[3]) == "full") {
            item->setPreferredRepresentation(item->fullRepresentation());
            item->setSize(QSizeF(320, 360));
            window.resize(368, 408);
        } else if (argc > 3) {
            if (auto *popup = item->findChild<QObject *>(QStringLiteral("meoLauncherPopup"))) {
                QMetaObject::invokeMethod(popup, QByteArray(argv[3]) == "search"
                    ? "openQuickSearch" : "toggleFullLauncher");
            }
        }
    });
    QTimer::singleShot(3000, &app, [&] {
        qInfo() << "Applet" << item->metaObject()->className()
                << "compact" << item->compactRepresentationItem()
                << "full" << item->fullRepresentationItem();
        if (!item->compactRepresentationItem() && !item->fullRepresentationItem()) { app.exit(7); return; }
        QQuickWindow *capture = &window;
        for (auto *candidate : QGuiApplication::allWindows()) {
            auto *quick = qobject_cast<QQuickWindow *>(candidate);
            if (quick && quick->isVisible() && quick->width() > capture->width()) capture = quick;
        }
        const bool saved = capture->grabWindow().save(QString::fromLocal8Bit(argv[2]));
        app.exit(saved && !QByteArray(item->metaObject()->className()).startsWith("AppletError") ? 0 : 5);
    });
    return app.exec();
}
