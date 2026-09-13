/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "screencoordinator.h"

#include <QCursor>
#include <QGuiApplication>
#include <QScreen>
#include <QTimer>
#include <QWindow>

#include <algorithm>

ScreenCoordinator::ScreenCoordinator(QObject *parent)
    : QObject(parent)
{
    auto *application = qGuiApp;
    if (!application) {
        return;
    }

    // KScreenLocker creates and destroys the actual secure windows. These
    // hooks merely pick another existing surface after a topology change.
    connect(application, &QGuiApplication::screenAdded, this, [this](QScreen *) {
        reconcileTopology();
    });
    connect(application, &QGuiApplication::screenRemoved, this, [this](QScreen *) {
        reconcileTopology(m_authenticationRequested);
    });
}

QString ScreenCoordinator::policy() const
{
    return policyName(m_policy);
}

void ScreenCoordinator::setPolicy(const QString &value)
{
    const Policy nextPolicy = normalizedPolicy(value);
    if (nextPolicy == m_policy) {
        return;
    }

    m_policy = nextPolicy;
    Q_EMIT policyChanged();
    reconcileTopology(m_authenticationRequested);
    bumpRevision();
}

bool ScreenCoordinator::authenticationRequested() const
{
    return m_authenticationRequested;
}

int ScreenCoordinator::registeredSurfaceCount() const
{
    int count = 0;
    for (const auto &surface : m_surfaces) {
        if (isEligible(surface)) {
            ++count;
        }
    }
    return count;
}

int ScreenCoordinator::revision() const
{
    return m_revision;
}

void ScreenCoordinator::registerSurface(QWindow *surface)
{
    if (!surface || containsSurface(surface)) {
        return;
    }

    m_surfaces.append(surface);
    connect(surface, &QWindow::screenChanged, this, [this](QScreen *) {
        reconcileTopology(m_authenticationRequested);
    });
    connect(surface, &QObject::destroyed, this, [this, surface] {
        unregisterSurface(surface);
    });

    Q_EMIT topologyChanged();
    reconcileTopology();
    bumpRevision();
}

void ScreenCoordinator::unregisterSurface(QWindow *surface)
{
    const bool wasActive = m_activeSurface == surface || m_activeSurfaceAddress == surface;
    const auto newEnd = std::remove_if(m_surfaces.begin(), m_surfaces.end(), [surface](const QPointer<QWindow> &candidate) {
        return candidate.isNull() || candidate == surface;
    });
    if (newEnd == m_surfaces.end()) {
        return;
    }

    m_surfaces.erase(newEnd, m_surfaces.end());
    Q_EMIT topologyChanged();
    if (wasActive) {
        m_activeSurface = nullptr;
        m_activeSurfaceAddress = nullptr;
    }
    reconcileTopology(wasActive && m_authenticationRequested);
    bumpRevision();
}

void ScreenCoordinator::requestAuthenticationOn(QWindow *surface)
{
    if (!isEligible(surface)) {
        return;
    }

    if (!m_authenticationRequested) {
        m_authenticationRequested = true;
        Q_EMIT authenticationRequestedChanged();
    }

    // Under fixed-primary policy, interaction on a secondary screen is an
    // intentionally harmless request that focuses the configured primary.
    QWindow *target = surface;
    if (m_policy == Policy::FixedPrimary) {
        target = surfaceForScreen(QGuiApplication::primaryScreen());
        if (!target) {
            target = preferredSurface();
        }
    }
    setActiveSurface(target, true);
    bumpRevision();
}

void ScreenCoordinator::dismissAuthentication()
{
    if (!m_authenticationRequested) {
        return;
    }
    m_authenticationRequested = false;
    Q_EMIT authenticationRequestedChanged();
    bumpRevision();
}

bool ScreenCoordinator::isSurfaceActive(QWindow *surface) const
{
    return surface && surface == m_activeSurface && isEligible(surface);
}

QWindow *ScreenCoordinator::activeSurface() const
{
    return m_activeSurface;
}

bool ScreenCoordinator::containsSurface(QWindow *surface) const
{
    return std::any_of(m_surfaces.cbegin(), m_surfaces.cend(), [surface](const QPointer<QWindow> &candidate) {
        return candidate == surface;
    });
}

bool ScreenCoordinator::isEligible(QWindow *surface) const
{
    if (!surface || !surface->screen()) {
        return false;
    }
    return QGuiApplication::screens().contains(surface->screen());
}

QVector<QWindow *> ScreenCoordinator::eligibleSurfaces() const
{
    QVector<QWindow *> surfaces;
    surfaces.reserve(m_surfaces.size());
    for (const auto &surface : m_surfaces) {
        if (isEligible(surface)) {
            surfaces.append(surface);
        }
    }
    return surfaces;
}

QWindow *ScreenCoordinator::surfaceForScreen(QScreen *screen) const
{
    if (!screen) {
        return nullptr;
    }
    for (const auto &surface : m_surfaces) {
        if (isEligible(surface) && surface->screen() == screen) {
            return surface;
        }
    }
    return nullptr;
}

QWindow *ScreenCoordinator::preferredSurface() const
{
    if (m_policy == Policy::FixedPrimary) {
        if (auto *primary = surfaceForScreen(QGuiApplication::primaryScreen())) {
            return primary;
        }
    }

    if (auto *atPointer = surfaceForScreen(QGuiApplication::screenAt(QCursor::pos()))) {
        return atPointer;
    }
    if (auto *primary = surfaceForScreen(QGuiApplication::primaryScreen())) {
        return primary;
    }

    const auto surfaces = eligibleSurfaces();
    return surfaces.isEmpty() ? nullptr : surfaces.constFirst();
}

void ScreenCoordinator::removeDestroyedSurfaces()
{
    const bool activeSurfaceWasDestroyed = m_activeSurface.isNull() && m_activeSurfaceAddress;
    const auto newEnd = std::remove_if(m_surfaces.begin(), m_surfaces.end(), [](const QPointer<QWindow> &surface) {
        return surface.isNull();
    });
    if (newEnd != m_surfaces.end()) {
        m_surfaces.erase(newEnd, m_surfaces.end());
        Q_EMIT topologyChanged();
    }
    if (activeSurfaceWasDestroyed) {
        m_activeSurfaceAddress = nullptr;
    }
}

void ScreenCoordinator::reconcileTopology(bool requestFocus)
{
    removeDestroyedSurfaces();
    if (m_activeSurface && isEligible(m_activeSurface) && m_policy != Policy::FixedPrimary) {
        return;
    }
    setActiveSurface(preferredSurface(), requestFocus);
}

void ScreenCoordinator::setActiveSurface(QWindow *surface, bool requestFocus)
{
    if (surface && !isEligible(surface)) {
        surface = nullptr;
    }
    const bool changed = m_activeSurface != surface;
    m_activeSurface = surface;
    m_activeSurfaceAddress = surface;
    if (changed) {
        Q_EMIT activeSurfaceChanged();
    }

    if (requestFocus && m_activeSurface) {
        // KScreenLocker retains the keyboard grab. Requesting activation here
        // only selects the existing secure window that receives that input.
        QPointer<QWindow> target = m_activeSurface;
        QTimer::singleShot(0, this, [this, target] {
            if (!target || target != m_activeSurface || !isEligible(target)) {
                return;
            }
            target->requestActivate();
            Q_EMIT focusRequested(target);
        });
    }
}

void ScreenCoordinator::bumpRevision()
{
    ++m_revision;
    Q_EMIT revisionChanged();
}

ScreenCoordinator::Policy ScreenCoordinator::normalizedPolicy(const QString &value)
{
    if (value == QStringLiteral("fixed-primary")) {
        return Policy::FixedPrimary;
    }
    if (value == QStringLiteral("follow-interaction")) {
        return Policy::FollowInteraction;
    }
    return Policy::Auto;
}

QString ScreenCoordinator::policyName(Policy policy)
{
    switch (policy) {
    case Policy::FixedPrimary:
        return QStringLiteral("fixed-primary");
    case Policy::FollowInteraction:
        return QStringLiteral("follow-interaction");
    case Policy::Auto:
    default:
        return QStringLiteral("auto");
    }
}
