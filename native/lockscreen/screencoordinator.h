/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QPointer>
#include <QVector>
#include <QWindow>

class QScreen;

// Coordinates only the visual authentication host across KScreenLocker's
// already-created secure windows. It deliberately has no password, PAM,
// authenticator, D-Bus, or persistent display-identity API.
class ScreenCoordinator final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "ScreenCoordinator")
    Q_CLASSINFO("QML.Singleton", "true")

    Q_PROPERTY(QString policy READ policy WRITE setPolicy NOTIFY policyChanged)
    Q_PROPERTY(bool authenticationRequested READ authenticationRequested NOTIFY authenticationRequestedChanged)
    Q_PROPERTY(int registeredSurfaceCount READ registeredSurfaceCount NOTIFY topologyChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    explicit ScreenCoordinator(QObject *parent = nullptr);

    QString policy() const;
    void setPolicy(const QString &policy);
    bool authenticationRequested() const;
    int registeredSurfaceCount() const;
    int revision() const;

    // The QML theme passes KScreenLocker's per-screen QQuickWindow context
    // object. A caller never provides EDID, geometry, password, or a durable
    // output key.
    Q_INVOKABLE void registerSurface(QWindow *surface);
    Q_INVOKABLE void unregisterSurface(QWindow *surface);
    Q_INVOKABLE void requestAuthenticationOn(QWindow *surface);
    Q_INVOKABLE void dismissAuthentication();
    Q_INVOKABLE bool isSurfaceActive(QWindow *surface) const;

    QWindow *activeSurface() const;

Q_SIGNALS:
    void policyChanged();
    void authenticationRequestedChanged();
    void topologyChanged();
    void revisionChanged();
    void activeSurfaceChanged();
    void focusRequested(QWindow *surface);

private:
    enum class Policy {
        Auto,
        FixedPrimary,
        FollowInteraction,
    };

    bool containsSurface(QWindow *surface) const;
    bool isEligible(QWindow *surface) const;
    QVector<QWindow *> eligibleSurfaces() const;
    QWindow *surfaceForScreen(QScreen *screen) const;
    QWindow *preferredSurface() const;
    void removeDestroyedSurfaces();
    void reconcileTopology(bool requestFocus = false);
    void setActiveSurface(QWindow *surface, bool requestFocus);
    void bumpRevision();
    static Policy normalizedPolicy(const QString &policy);
    static QString policyName(Policy policy);

    QVector<QPointer<QWindow>> m_surfaces;
    QPointer<QWindow> m_activeSurface;
    // QPointer clears before QObject::destroyed(). Keep the last address only
    // for equality during that signal; it is never dereferenced once null.
    QWindow *m_activeSurfaceAddress = nullptr;
    Policy m_policy = Policy::Auto;
    bool m_authenticationRequested = false;
    int m_revision = 0;
};
