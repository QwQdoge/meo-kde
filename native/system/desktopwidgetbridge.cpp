#include "desktopwidgetbridge.h"

#include <KLocalizedString>
#include <plasma/containment.h>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>

#include <array>

namespace
{
struct MeoWidgetDefinition {
    const char *id;
    const char *pluginId;
    const char *title;
    const char *description;
    const char *iconName;
    const char *previewKind;
    const char *lockScreenAdapter;
    QSizeF defaultSize;
    bool sharedWithLockScreen;
};

// This is the Meo registry, not a replacement Plasma registry. Each entry is
// a MeoUI contract rendered by a first-party adapter package on desktop. A
// lock screen, when listed, loads the named reviewed adapter instead of the
// desktop applet package.
const std::array<MeoWidgetDefinition, 3> kMeoWidgetCatalog = {
    MeoWidgetDefinition{"clock", "org.meo.widget.clock", "Meo clock",
                        "Large date, time, and optional cached weather.",
                        "schedule", "clock", "MeoAmbientClock", QSizeF(320, 224), true},
    MeoWidgetDefinition{"media", "org.meo.widget.media", "Meo media",
                        "Current-session MPRIS controls with bounded local artwork.",
                        "music_note", "media", "MeoMediaController", QSizeF(384, 176), true},
    MeoWidgetDefinition{"performance", "org.meo.widget.performance", "Meo performance",
                        "Live CPU, memory, GPU, storage, and network performance.",
                        "monitoring", "performance", "", QSizeF(500, 330), false},
};

const MeoWidgetDefinition *meoDefinitionFor(const QString &id)
{
    for (const auto &definition : kMeoWidgetCatalog) {
        if (id == QLatin1String(definition.id)) {
            return &definition;
        }
    }
    return nullptr;
}

bool safePluginId(const QString &pluginId)
{
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._-]*$"));
    return pattern.match(pluginId).hasMatch();
}

bool appletPackageIsInstalled(const QString &pluginId)
{
    if (!safePluginId(pluginId)) {
        return false;
    }
    const QString relativePath = QStringLiteral("plasma/plasmoids/%1/metadata.json").arg(pluginId);
    return !QStandardPaths::locateAll(QStandardPaths::GenericDataLocation,
                                      relativePath,
                                      QStandardPaths::LocateFile)
                .isEmpty();
}

QString localizedMetadataValue(const QJsonValue &value, const QString &locale)
{
    if (value.isString()) {
        return value.toString();
    }
    if (!value.isObject()) {
        return {};
    }

    const QJsonObject translations = value.toObject();
    if (translations.contains(locale)) {
        return translations.value(locale).toString();
    }
    const QString language = locale.section(QLatin1Char('_'), 0, 0);
    if (translations.contains(language)) {
        return translations.value(language).toString();
    }
    return translations.value(QStringLiteral("en")).toString();
}

QString localizedMetadataString(const QJsonObject &metadata, const QString &key)
{
    const QString locale = QLocale().name();
    const QString language = locale.section(QLatin1Char('_'), 0, 0);
    const QStringList localizedKeys{
        key + QLatin1Char('[') + locale + QLatin1Char(']'),
        key + QLatin1Char('[') + language + QLatin1Char(']'),
    };
    for (const QString &localizedKey : localizedKeys) {
        const QJsonValue localizedValue = metadata.value(localizedKey);
        if (localizedValue.isString() && !localizedValue.toString().isEmpty()) {
            return localizedValue.toString();
        }
    }

    return localizedMetadataValue(metadata.value(key), locale);
}

bool supportsDesktop(const QJsonObject &plugin)
{
    const QJsonValue formFactorsValue = plugin.value(QStringLiteral("FormFactors"));
    if (formFactorsValue.isUndefined() || formFactorsValue.isNull()) {
        return true;
    }
    const QJsonArray formFactors = formFactorsValue.toArray();
    if (formFactors.isEmpty()) {
        return true;
    }
    for (const QJsonValue &formFactor : formFactors) {
        if (formFactor.toString() == QLatin1String("desktop")) {
            return true;
        }
    }
    return false;
}

QRectF normalizedGeometry(const QRectF &geometryHint, const QSizeF &fallbackSize)
{
    QRectF geometry = geometryHint.normalized();
    if (geometry.width() < 1 || geometry.height() < 1) {
        geometry.setSize(fallbackSize);
    }

    geometry.setWidth(qBound(96.0, geometry.width(), 720.0));
    geometry.setHeight(qBound(96.0, geometry.height(), 720.0));
    geometry.moveLeft(qMax(0.0, geometry.x()));
    geometry.moveTop(qMax(0.0, geometry.y()));
    return geometry;
}

QSet<QString> meoPluginIds()
{
    QSet<QString> ids;
    for (const auto &definition : kMeoWidgetCatalog) {
        ids.insert(QLatin1String(definition.pluginId));
    }
    return ids;
}
}

DesktopWidgetBridge::DesktopWidgetBridge(QObject *parent,
                                         QStringList dataLocationsOverride)
    : QObject(parent)
    , m_dataLocationsOverride(dataLocationsOverride)
{
    refreshPlasmaCatalog();
}

QVariantList DesktopWidgetBridge::meoCatalog() const
{
    QVariantList entries;
    entries.reserve(static_cast<qsizetype>(kMeoWidgetCatalog.size()));
    for (const auto &definition : kMeoWidgetCatalog) {
        const QString pluginId = QLatin1String(definition.pluginId);
        entries.push_back(QVariantMap{
            {QStringLiteral("host"), QStringLiteral("meo")},
            {QStringLiteral("id"), QLatin1String(definition.id)},
            {QStringLiteral("pluginId"), pluginId},
            {QStringLiteral("title"), i18nd("meo-desktop", definition.title)},
            {QStringLiteral("description"), i18nd("meo-desktop", definition.description)},
            {QStringLiteral("icon"), QLatin1String(definition.iconName)},
            {QStringLiteral("previewKind"), QLatin1String(definition.previewKind)},
            {QStringLiteral("sharedWithLockScreen"), definition.sharedWithLockScreen},
            {QStringLiteral("lockScreenEligible"), definition.sharedWithLockScreen},
            {QStringLiteral("lockScreenAdapter"), QLatin1String(definition.lockScreenAdapter)},
            {QStringLiteral("available"), appletPackageIsInstalled(pluginId)},
            {QStringLiteral("defaultWidth"), definition.defaultSize.width()},
            {QStringLiteral("defaultHeight"), definition.defaultSize.height()},
            {QStringLiteral("presentationModes"), QStringList{QStringLiteral("meoFramed"), QStringLiteral("adaptive")}},
        });
    }
    return entries;
}

QVariantList DesktopWidgetBridge::plasmaCatalog() const
{
    return m_plasmaCatalog;
}

QVariantList DesktopWidgetBridge::catalog() const
{
    QVariantList entries = meoCatalog();
    entries.append(m_plasmaCatalog);
    return entries;
}

QString DesktopWidgetBridge::lastError() const
{
    return m_lastError;
}

void DesktopWidgetBridge::refreshPlasmaCatalog()
{
    QVariantList catalog;
    QSet<QString> pluginIds;
    QSet<QString> seenIds;
    const QSet<QString> firstPartyMeoIds = meoPluginIds();
    const QStringList dataLocations = m_dataLocationsOverride.isEmpty()
        ? QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)
        : m_dataLocationsOverride;
    const QString userDataLocation = QDir::cleanPath(
        m_dataLocationsOverride.isEmpty()
            ? QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            : dataLocations.constFirst());

    // QStandardPaths preserves KDE's normal user-before-system lookup order,
    // so a user-installed KNewStuff package shadows the system package just
    // as it does in Plasma itself. The package is still loaded by Plasma's
    // real Applet/Containment lifecycle below; Meo never emulates its QML API.
    for (const QString &dataLocation : dataLocations) {
        const QDir appletRoot(QDir(dataLocation).filePath(QStringLiteral("plasma/plasmoids")));
        if (!appletRoot.exists()) {
            continue;
        }

        const QStringList packageDirectories = appletRoot.entryList(
            QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
        for (const QString &packageDirectory : packageDirectories) {
            const QString packagePath = appletRoot.filePath(packageDirectory);
            const QString metadataPath = QDir(packagePath).filePath(QStringLiteral("metadata.json"));
            QFile metadataFile(metadataPath);
            if (!metadataFile.open(QIODevice::ReadOnly)) {
                continue;
            }

            QJsonParseError parseError;
            const QJsonDocument document = QJsonDocument::fromJson(metadataFile.readAll(), &parseError);
            if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
                continue;
            }
            const QJsonObject metadata = document.object();
            if (metadata.value(QStringLiteral("KPackageStructure")).toString()
                != QLatin1String("Plasma/Applet")) {
                continue;
            }
            const QJsonObject plugin = metadata.value(QStringLiteral("KPlugin")).toObject();
            const QString pluginId = plugin.value(QStringLiteral("Id")).toString();
            if (!safePluginId(pluginId) || pluginId != packageDirectory
                || seenIds.contains(pluginId) || firstPartyMeoIds.contains(pluginId)
                // A desktop containment is a package with the same package
                // structure as an applet, but is not itself a desktop widget
                // that can be placed inside this existing containment.
                || !metadata.value(QStringLiteral("X-Plasma-ContainmentType")).toString().isEmpty()
                || !supportsDesktop(plugin)
                || !QFileInfo::exists(QDir(packagePath).filePath(QStringLiteral("contents/ui/main.qml")))) {
                continue;
            }

            seenIds.insert(pluginId);
            pluginIds.insert(pluginId);
            const QString title = localizedMetadataString(plugin, QStringLiteral("Name"));
            const QString description = localizedMetadataString(plugin, QStringLiteral("Description"));
            const QString normalizedPackagePath = QDir::cleanPath(packagePath);
            const bool isUserPackage = normalizedPackagePath == userDataLocation
                || normalizedPackagePath.startsWith(userDataLocation + QLatin1Char('/'));
            catalog.push_back(QVariantMap{
                {QStringLiteral("host"), QStringLiteral("plasma")},
                {QStringLiteral("id"), pluginId},
                {QStringLiteral("pluginId"), pluginId},
                {QStringLiteral("title"), title.isEmpty() ? pluginId : title},
                {QStringLiteral("description"), description},
                {QStringLiteral("icon"), plugin.value(QStringLiteral("Icon")).toString()},
                {QStringLiteral("source"), isUserPackage ? QStringLiteral("user") : QStringLiteral("system")},
                {QStringLiteral("available"), true},
                {QStringLiteral("sharedWithLockScreen"), false},
                {QStringLiteral("lockScreenEligible"), false},
                {QStringLiteral("lockScreenAdapter"), QString()},
                {QStringLiteral("compatibilityMode"), true},
                // The normal Plasma item remains visually native today. A
                // real containment presentation layer will consume these
                // modes later; the explorer does not pretend to recolour
                // third-party QML before that layer exists.
                {QStringLiteral("presentationModes"), QStringList{QStringLiteral("native"), QStringLiteral("meoFramed"), QStringLiteral("adaptive")}},
            });
        }
    }

    const bool changed = catalog != m_plasmaCatalog;
    m_plasmaCatalog = catalog;
    m_discoveredPlasmaPluginIds = pluginIds;
    if (changed) {
        Q_EMIT plasmaCatalogChanged();
        Q_EMIT catalogChanged();
    }
}

bool DesktopWidgetBridge::addMeoWidget(QObject *desktopContainment,
                                       const QString &widgetId,
                                       const QRectF &geometryHint)
{
    const MeoWidgetDefinition *definition = meoDefinitionFor(widgetId);
    if (!definition) {
        setError(i18nd("meo-desktop", "This widget is not in the Meo widget registry."));
        return false;
    }
    return addApplet(desktopContainment, QLatin1String(definition->pluginId),
                     normalizedGeometry(geometryHint, definition->defaultSize),
                     QStringLiteral("meo"), widgetId);
}

bool DesktopWidgetBridge::addPlasmaWidget(QObject *desktopContainment,
                                          const QString &pluginId,
                                          const QRectF &geometryHint)
{
    // Refresh immediately before creation: installing/removing a Store
    // package between opening and clicking Widget Explorer cannot turn QML
    // input into an arbitrary package-ID escape hatch.
    refreshPlasmaCatalog();
    if (!safePluginId(pluginId) || !m_discoveredPlasmaPluginIds.contains(pluginId)) {
        setError(i18nd("meo-desktop", "This Plasma widget is not available from a standard Plasma package location."));
        return false;
    }
    return addApplet(desktopContainment, pluginId,
                     normalizedGeometry(geometryHint, QSizeF(320, 220)),
                     QStringLiteral("plasma"), pluginId);
}

bool DesktopWidgetBridge::addApplet(QObject *desktopContainment,
                                    const QString &pluginId,
                                    const QRectF &geometry,
                                    const QString &host,
                                    const QString &entryId)
{
    auto *containment = qobject_cast<Plasma::Containment *>(desktopContainment);
    if (!containment || containment->containmentType() != Plasma::Containment::Desktop) {
        setError(i18nd("meo-desktop", "Widgets can only be added to a desktop surface."));
        return false;
    }
    if (!appletPackageIsInstalled(pluginId)) {
        setError(i18nd("meo-desktop", "The required widget package is not installed."));
        return false;
    }
    if (!containment->createApplet(pluginId, {}, geometry)) {
        setError(i18nd("meo-desktop", "Plasma could not create this widget."));
        return false;
    }

    clearError();
    Q_EMIT widgetAdded(host, entryId);
    return true;
}

void DesktopWidgetBridge::clearError()
{
    if (!lastError().isEmpty()) {
        m_lastError.clear();
        Q_EMIT lastErrorChanged();
    }
}

void DesktopWidgetBridge::setError(const QString &error)
{
    if (lastError() == error) {
        return;
    }
    m_lastError = error;
    Q_EMIT lastErrorChanged();
}
