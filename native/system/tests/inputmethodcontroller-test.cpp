#include "inputmethodcontroller.h"

#include <QtTest>

class InputMethodControllerTest final : public QObject
{
    Q_OBJECT

private Q_SLOTS:
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
