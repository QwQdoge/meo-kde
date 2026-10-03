#include "router.h"

#include <QSignalSpy>
#include <QTest>

class RouterTest final : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void ordinaryActionRunsWithoutPrompt();
    void reversiblePersistentActionRunsWithoutRouterPrompt();
    void unknownAndMalformedAreRejected();
    void irreversibleDisabledInProduction();
    void irreversibleRequiresMatchingApproval();
    void denialAndExpiryNeverDispatch();
};

static Router::Capability capability(Router::Effect effect, int *calls)
{
    Router::Capability entry;
    entry.id = QStringLiteral("org.meo.test.action");
    entry.title = QStringLiteral("Change target");
    entry.impact = QStringLiteral("This cannot be undone");
    entry.effect = effect;
    entry.arguments = {{QStringLiteral("target"), QMetaType::QString}};
    entry.describeTarget = [](const QVariantMap &arguments) {
        return arguments.value(QStringLiteral("target")).toString();
    };
    entry.dispatch = [calls](const QString &, const QVariantMap &) { ++*calls; };
    return entry;
}

void RouterTest::ordinaryActionRunsWithoutPrompt()
{
    Router router;
    int calls = 0;
    QVERIFY(router.addCapability(capability(Router::Effect::Session, &calls)));
    QSignalSpy confirmation(&router, &Router::confirmationRequired);
    const auto result = router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("app.desktop")}}, QStringLiteral(":1.1"));
    QCOMPARE(result.value(QStringLiteral("state")).toString(), QStringLiteral("running"));
    QCOMPARE(calls, 1);
    QCOMPARE(confirmation.size(), 0);
}

void RouterTest::reversiblePersistentActionRunsWithoutRouterPrompt()
{
    Router router;
    int calls = 0;
    QVERIFY(router.addCapability(capability(Router::Effect::Persistent, &calls)));
    QSignalSpy confirmation(&router, &Router::confirmationRequired);
    const auto result = router.submit(QStringLiteral("org.meo.test.action"),
        {{QStringLiteral("target"), QStringLiteral("reversible setting")}},
        QStringLiteral(":1.1"));
    QCOMPARE(result.value(QStringLiteral("state")).toString(), QStringLiteral("running"));
    QCOMPARE(confirmation.size(), 0);
    QCOMPARE(calls, 1);
}

void RouterTest::unknownAndMalformedAreRejected()
{
    Router router;
    int calls = 0;
    QVERIFY(router.addCapability(capability(Router::Effect::Session, &calls)));
    QCOMPARE(router.submit(QStringLiteral("org.meo.fake"), {}, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("rejected"));
    QCOMPARE(router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), 3}}, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("rejected"));
    QCOMPARE(router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("a")}, {QStringLiteral("extra"), true}}, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("rejected"));
    QCOMPARE(calls, 0);
}

void RouterTest::irreversibleDisabledInProduction()
{
    Router router;
    int calls = 0;
    QVERIFY(router.addCapability(capability(Router::Effect::Irreversible, &calls)));
    QCOMPARE(router.capabilities().size(), 0);
    QCOMPARE(router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("x")}}, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("rejected"));
    QCOMPARE(calls, 0);
}

void RouterTest::irreversibleRequiresMatchingApproval()
{
    Router router(true);
    int calls = 0;
    QVERIFY(router.addCapability(capability(Router::Effect::Irreversible, &calls)));
    QSignalSpy confirmation(&router, &Router::confirmationRequired);
    const auto request = router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("x")}}, QStringLiteral(":1.1"));
    QCOMPARE(request.value(QStringLiteral("state")).toString(), QStringLiteral("awaiting_confirmation"));
    QCOMPARE(confirmation.size(), 1);
    QCOMPARE(calls, 0);
    const QString id = request.value(QStringLiteral("requestId")).toString();
    QCOMPARE(router.decide(id, request.value(QStringLiteral("fingerprint")).toString(), true, QStringLiteral(":1.2")).value(QStringLiteral("state")).toString(), QStringLiteral("rejected"));
    QCOMPARE(router.decide(id, QStringLiteral("changed"), true, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("rejected"));
    QCOMPARE(calls, 0);
    const auto accepted = router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("y")}}, QStringLiteral(":1.1"));
    QCOMPARE(accepted.value(QStringLiteral("target")).toString(), QStringLiteral("y"));
    QVERIFY(accepted.value(QStringLiteral("fingerprint")) != request.value(QStringLiteral("fingerprint")));
    QCOMPARE(router.decide(accepted.value(QStringLiteral("requestId")).toString(),
        request.value(QStringLiteral("fingerprint")).toString(), true,
        QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("rejected"));
    QCOMPARE(calls, 0);
    const auto matching = router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("y")}}, QStringLiteral(":1.1"));
    QCOMPARE(router.decide(matching.value(QStringLiteral("requestId")).toString(), matching.value(QStringLiteral("fingerprint")).toString(), true, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("running"));
    QCOMPARE(calls, 1);
}

void RouterTest::denialAndExpiryNeverDispatch()
{
    Router router(true);
    int calls = 0;
    QVERIFY(router.addCapability(capability(Router::Effect::Irreversible, &calls)));
    const auto denied = router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("x")}}, QStringLiteral(":1.1"));
    const QString deniedId = denied.value(QStringLiteral("requestId")).toString();
    QCOMPARE(router.decide(deniedId, denied.value(QStringLiteral("fingerprint")).toString(), false, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("denied"));
    QCOMPARE(router.decide(deniedId, denied.value(QStringLiteral("fingerprint")).toString(), true, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("denied"));
    const auto expiring = router.submit(QStringLiteral("org.meo.test.action"), {{QStringLiteral("target"), QStringLiteral("y")}}, QStringLiteral(":1.1"));
    router.expirePending(QDateTime::currentDateTimeUtc().addSecs(31));
    QCOMPARE(router.decide(expiring.value(QStringLiteral("requestId")).toString(), expiring.value(QStringLiteral("fingerprint")).toString(), true, QStringLiteral(":1.1")).value(QStringLiteral("state")).toString(), QStringLiteral("expired"));
    QCOMPARE(calls, 0);
}

QTEST_GUILESS_MAIN(RouterTest)
#include "router-test.moc"
