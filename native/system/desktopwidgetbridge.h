#pragma once

#include <QObject>
#include <QRectF>
#include <QSet>
#include <QStringList>
#include <QVariantList>

// The Meo Widget Explorer bridge has two real hosts:
//
// - Meo entries are stable MeoUI widget contracts mapped to first-party Plasma
//   applet adapters.
// - Plasma entries are discovered from Plasma's standard package locations
//   and created by Plasma::Containment itself.
//
// It intentionally has no panel/Dock path. Generic Plasma packages are
// desktop-only and cannot cross the KScreenLocker trust boundary.
class DesktopWidgetBridge final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "DesktopWidgets")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(QVariantList meoCatalog READ meoCatalog CONSTANT)
    Q_PROPERTY(QVariantList plasmaCatalog READ plasmaCatalog NOTIFY plasmaCatalogChanged)
    Q_PROPERTY(QVariantList catalog READ catalog NOTIFY catalogChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit DesktopWidgetBridge(QObject *parent = nullptr,
                                 QStringList dataLocationsOverride = {});

    QVariantList meoCatalog() const;
    QVariantList plasmaCatalog() const;
    QVariantList catalog() const;
    QString lastError() const;

    Q_INVOKABLE void refreshPlasmaCatalog();
    Q_INVOKABLE bool addMeoWidget(QObject *desktopContainment,
                                  const QString &widgetId,
                                  const QRectF &geometryHint = QRectF());
    Q_INVOKABLE bool addPlasmaWidget(QObject *desktopContainment,
                                     const QString &pluginId,
                                     const QRectF &geometryHint = QRectF());
    Q_INVOKABLE void clearError();

Q_SIGNALS:
    void plasmaCatalogChanged();
    void catalogChanged();
    void lastErrorChanged();
    void widgetAdded(const QString &host, const QString &entryId);

private:
    bool addApplet(QObject *desktopContainment,
                   const QString &pluginId,
                   const QRectF &geometry,
                   const QString &host,
                   const QString &entryId);
    void setError(const QString &error);

    QVariantList m_plasmaCatalog;
    QSet<QString> m_discoveredPlasmaPluginIds;
    QStringList m_dataLocationsOverride;
    QString m_lastError;
};
