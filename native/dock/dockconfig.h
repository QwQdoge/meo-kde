#pragma once

#include <QObject>
#include <QStringList>
#include <QUrl>

class DockConfig final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.meo.Dock")
    Q_PROPERTY(QStringList launcherList READ launcherList WRITE setLauncherList NOTIFY launcherListChanged)
    Q_PROPERTY(QString globalIconMode READ globalIconMode WRITE setGlobalIconMode NOTIFY globalIconModeChanged)
    Q_PROPERTY(bool reduceMotion READ reduceMotion NOTIFY reduceMotionChanged)

public:
    explicit DockConfig(QObject *parent = nullptr);

    QStringList launcherList() const;
    void setLauncherList(const QStringList &launchers);

    QString globalIconMode() const;
    void setGlobalIconMode(const QString &mode);
    bool reduceMotion() const;
    bool shouldShow() const;

    Q_INVOKABLE QString iconModeFor(const QString &appId, const QUrl &launcherUrl) const;
    Q_INVOKABLE void setIconModeFor(const QString &appId, const QUrl &launcherUrl,
                                    const QString &mode);
    Q_INVOKABLE void activateLauncherMenu();
    Q_INVOKABLE void reload();

    static bool isSupportedIconMode(const QString &mode);
    static QString stableApplicationId(const QString &appId, const QUrl &launcherUrl);
    static QString configKeyForApplication(const QString &appId, const QUrl &launcherUrl);

public Q_SLOTS:
    void Quit();

Q_SIGNALS:
    void launcherListChanged();
    void globalIconModeChanged();
    void reduceMotionChanged();
    void iconOverridesChanged();

private:
    QStringList migratedLauncherList() const;

    QStringList m_launcherList;
    QString m_globalIconMode = QStringLiteral("original");
    bool m_reduceMotion = false;
};
