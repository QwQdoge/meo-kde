/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "../screencoordinator.h"

#include <QGuiApplication>
#include <QSignalSpy>
#include <QTest>
#include <QWindow>

class ScreenCoordinatorTest final : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void choosesOnlyOneAuthenticationSurface();
    void activeSurfaceRemovalMovesFocusToRemainingSurface();
    void destroyedActiveSurfaceMovesFocusToRemainingSurface();
    void fixedPrimaryRejectsSecondaryAuthenticationHost();
    void dismissingPresentationDoesNotChangeTopology();
};

void ScreenCoordinatorTest::choosesOnlyOneAuthenticationSurface()
{
    ScreenCoordinator coordinator;
    QWindow first;
    QWindow second;
    QWindow third;
    coordinator.registerSurface(&first);
    coordinator.registerSurface(&second);
    coordinator.registerSurface(&third);

    coordinator.requestAuthenticationOn(&second);

    QVERIFY(coordinator.authenticationRequested());
    QCOMPARE(coordinator.registeredSurfaceCount(), 3);
    QVERIFY(coordinator.isSurfaceActive(&second));
    QVERIFY(!coordinator.isSurfaceActive(&first));
    QVERIFY(!coordinator.isSurfaceActive(&third));
}

void ScreenCoordinatorTest::activeSurfaceRemovalMovesFocusToRemainingSurface()
{
    ScreenCoordinator coordinator;
    QWindow first;
    QWindow second;
    coordinator.registerSurface(&first);
    coordinator.registerSurface(&second);
    coordinator.requestAuthenticationOn(&second);

    QSignalSpy focusSpy(&coordinator, &ScreenCoordinator::focusRequested);
    coordinator.unregisterSurface(&second);
    QTRY_COMPARE(focusSpy.size(), 1);

    QCOMPARE(coordinator.registeredSurfaceCount(), 1);
    QVERIFY(coordinator.authenticationRequested());
    QVERIFY(coordinator.isSurfaceActive(&first));
    QCOMPARE(focusSpy.at(0).at(0).value<QWindow *>(), &first);
}

void ScreenCoordinatorTest::destroyedActiveSurfaceMovesFocusToRemainingSurface()
{
    ScreenCoordinator coordinator;
    QWindow first;
    auto *second = new QWindow;
    coordinator.registerSurface(&first);
    coordinator.registerSurface(second);
    coordinator.requestAuthenticationOn(second);

    QSignalSpy focusSpy(&coordinator, &ScreenCoordinator::focusRequested);
    delete second;
    QTRY_COMPARE(focusSpy.size(), 1);

    QCOMPARE(coordinator.registeredSurfaceCount(), 1);
    QVERIFY(coordinator.authenticationRequested());
    QVERIFY(coordinator.isSurfaceActive(&first));
    QCOMPARE(focusSpy.at(0).at(0).value<QWindow *>(), &first);
}

void ScreenCoordinatorTest::fixedPrimaryRejectsSecondaryAuthenticationHost()
{
    ScreenCoordinator coordinator;
    QWindow first;
    QWindow second;
    coordinator.registerSurface(&first);
    coordinator.registerSurface(&second);
    coordinator.setPolicy(QStringLiteral("fixed-primary"));

    coordinator.requestAuthenticationOn(&second);

    // The offscreen test platform has one primary QScreen. The first surface
    // registered for it is therefore the deterministic primary host.
    QVERIFY(coordinator.isSurfaceActive(&first));
    QVERIFY(!coordinator.isSurfaceActive(&second));
    QCOMPARE(coordinator.policy(), QStringLiteral("fixed-primary"));
}

void ScreenCoordinatorTest::dismissingPresentationDoesNotChangeTopology()
{
    ScreenCoordinator coordinator;
    QWindow first;
    QWindow second;
    coordinator.registerSurface(&first);
    coordinator.registerSurface(&second);
    coordinator.requestAuthenticationOn(&second);
    const int countBeforeDismissal = coordinator.registeredSurfaceCount();

    coordinator.dismissAuthentication();

    QVERIFY(!coordinator.authenticationRequested());
    QCOMPARE(coordinator.registeredSurfaceCount(), countBeforeDismissal);
    QVERIFY(coordinator.isSurfaceActive(&second));
}

QTEST_MAIN(ScreenCoordinatorTest)

#include "screencoordinator-test.moc"
