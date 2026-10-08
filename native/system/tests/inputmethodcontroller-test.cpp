#include "inputmethodcontroller.h"

#include <QtTest>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVirtualObject>
#include <utility>
#include <QUuid>

// CTest launches this executable on a private D-Bus. Never register on a live
// desktop bus: require the explicit test-only marker as well as an actual bus.
class FakeFcitx final : public QDBusVirtualObject
{
public:
    QDBusConnection bus = QDBusConnection::connectToBus(
        QDBusConnection::SessionBus, QUuid::createUuid().toString());
    ~FakeFcitx() override
    {
        QDBusConnection::disconnectFromBus(bus.name());
    }
    int state = 1;
    int stateCalls = 0;
    QList<QDBusMessage> reloadCalls;

    QString introspect(const QString &) const override
    {
        return QStringLiteral("<interface name=\"org.fcitx.Fcitx.Controller1\">"
                              "<method name=\"State\"><arg type=\"i\" direction=\"out\"/></method>"
                              "<method name=\"ReloadConfig\"/>"
                              "</interface>");
    }

    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        if (message.member() == QStringLiteral("ReloadConfig")) {
            message.setDelayedReply(true);
            reloadCalls.push_back(message);
            return true;
        }
        QVariant value;
        if (message.member() == QStringLiteral("State")) {
            ++stateCalls;
            value = state;
        } else if (message.member() == QStringLiteral("InputMethodGroups")) {
            value = QStringList{};
        } else if (message.member() == QStringLiteral("CanRestart")) {
            value = false;
        } else if (message.member() == QStringLiteral("AvailableInputMethods")) {
            // Exercise an unavailable inventory independently of service state.
            connection.send(message.createErrorReply(
                QStringLiteral("org.fcitx.InventoryUnavailable"), QStringLiteral("fixture")));
            return true;
        } else {
            value = QString{};
        }
        connection.send(message.createReply(QList<QVariant>{value}));
        return true;
    }

    void completeReload()
    {
        const auto calls = std::exchange(reloadCalls, {});
        for (const auto &message : calls) {
            bus.send(message.createReply());
        }
    }
};

class InputMethodControllerTest final : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void activationUsesFcitxStateTwo()
    {
        QVERIFY(qEnvironmentVariableIsSet("MEO_INPUT_METHOD_TEST_BUS"));
        FakeFcitx fixture;
        auto bus = fixture.bus;
        QVERIFY(bus.isConnected());
        QVERIFY(bus.registerVirtualObject(QStringLiteral("/controller"), &fixture));
        QVERIFY(bus.registerService(QStringLiteral("org.fcitx.Fcitx5")));
        const auto cleanup = qScopeGuard([&] {
            bus.unregisterService(QStringLiteral("org.fcitx.Fcitx5"));
            bus.unregisterObject(QStringLiteral("/controller"));
        });
        InputMethodController controller;
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);
        QVERIFY(controller.available());
        QCOMPARE(fixture.stateCalls, 1);
        QVERIFY(!controller.active());
        fixture.state = 2;
        controller.refresh();
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);
        QVERIFY(controller.active());
        fixture.state = 0;
        controller.refresh();
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);
        QVERIFY(!controller.active());
    }

    void refreshCannotReleaseMutationOwnership()
    {
        QVERIFY(qEnvironmentVariableIsSet("MEO_INPUT_METHOD_TEST_BUS"));
        FakeFcitx fixture;
        auto bus = fixture.bus;
        QVERIFY(bus.isConnected());
        QVERIFY(bus.registerVirtualObject(QStringLiteral("/controller"), &fixture));
        QVERIFY(bus.registerService(QStringLiteral("org.fcitx.Fcitx5")));
        const auto cleanup = qScopeGuard([&] {
            fixture.completeReload();
            bus.unregisterService(QStringLiteral("org.fcitx.Fcitx5"));
            bus.unregisterObject(QStringLiteral("/controller"));
        });
        InputMethodController controller;
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);
        QVERIFY(controller.reload());
        QTRY_COMPARE_WITH_TIMEOUT(fixture.reloadCalls.size(), 1, 3000);
        controller.refresh();
        QTest::qWait(100);
        QVERIFY(controller.busy());
        QCOMPARE(fixture.stateCalls, 1);
        QVERIFY(!controller.reload());
        QCOMPARE(fixture.reloadCalls.size(), 1);
        fixture.completeReload();
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);
        QCOMPARE(fixture.stateCalls, 2);
    }

    void staleOwnerReplyCannotReleaseANewerOperation()
    {
        QVERIFY(qEnvironmentVariableIsSet("MEO_INPUT_METHOD_TEST_BUS"));
        FakeFcitx fixture;
        auto bus = fixture.bus;
        QVERIFY(bus.isConnected());
        QVERIFY(bus.registerVirtualObject(QStringLiteral("/controller"), &fixture));
        QVERIFY(bus.registerService(QStringLiteral("org.fcitx.Fcitx5")));
        const auto cleanup = qScopeGuard([&] {
            fixture.completeReload();
            bus.unregisterService(QStringLiteral("org.fcitx.Fcitx5"));
            bus.unregisterObject(QStringLiteral("/controller"));
        });
        InputMethodController controller;
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);
        QVERIFY(controller.reload());
        QTRY_COMPARE_WITH_TIMEOUT(fixture.reloadCalls.size(), 1, 3000);
        QVERIFY(bus.unregisterService(QStringLiteral("org.fcitx.Fcitx5")));
        QTRY_VERIFY_WITH_TIMEOUT(!controller.available(), 3000);
        QVERIFY(bus.registerService(QStringLiteral("org.fcitx.Fcitx5")));
        QTRY_VERIFY_WITH_TIMEOUT(controller.available() && !controller.busy(), 3000);
        QVERIFY(controller.reload());
        QTRY_COMPARE_WITH_TIMEOUT(fixture.reloadCalls.size(), 2, 3000);
        bus.send(fixture.reloadCalls.takeFirst().createReply());
        QTest::qWait(100);
        QVERIFY(controller.busy());
        QVERIFY(!controller.reload());
        fixture.completeReload();
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);
    }

    void invalidRequestsFailBeforeDbusMutation()
    {
        InputMethodController controller;

        QVERIFY(!controller.setCurrentInputMethod(QString{}));
        QVERIFY(!controller.lastError().isEmpty());

        controller.clearError();
        QVERIFY(!controller.setCurrentInputMethod(QString(300, QLatin1Char('x'))));
        QVERIFY(!controller.lastError().isEmpty());

        controller.clearError();
        QVERIFY(!controller.switchGroup(QStringLiteral("bad\ngroup")));
        QVERIFY(!controller.lastError().isEmpty());

        controller.clearError();
        QVERIFY(!controller.applyCurrentGroup({}, {}, QString{}));
        QVERIFY(!controller.lastError().isEmpty());
    }

    void unavailableServiceDoesNotInventInventory()
    {
        InputMethodController controller;
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 3000);

        if (!controller.available()) {
            QVERIFY(controller.groups().isEmpty());
            QVERIFY(controller.currentGroup().isEmpty());
            QVERIFY(controller.currentInputMethod().isEmpty());
            QVERIFY(controller.activeInputMethods().isEmpty());
            QVERIFY(controller.availableInputMethods().isEmpty());
        }
    }
};

QTEST_GUILESS_MAIN(InputMethodControllerTest)
#include "inputmethodcontroller-test.moc"
