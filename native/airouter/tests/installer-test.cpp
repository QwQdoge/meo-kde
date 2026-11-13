#include "installer.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QTest>

class InstallerTest final : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void init()
    {
        QVERIFY(m_dir.isValid());
        qputenv("MEO_INSTALLER_PROPOSAL_DIR", m_dir.path().toUtf8());
        qputenv("MEO_INSTALLER_LOG", (m_dir.path() + QStringLiteral("/install.log")).toUtf8());
    }
    void validProposalIsWritten();
    void accountAndPasswordFieldsAreRejected();
    void malformedValuesAreRejected();
    void stableDiskIdIsAcceptedAndPathTricksAreNot();
    void logReturnsTail();

private:
    QTemporaryDir m_dir;
};

void InstallerTest::validProposalIsWritten()
{
    QString message;
    QVERIFY(InstallerCapabilities::submitProposal(
        QStringLiteral(R"({"timezone":"Asia/Tokyo","filesystem":"btrfs","firewall":true,"rationale":"x"})"), &message));
    QFile file(InstallerCapabilities::proposalPath());
    QVERIFY(file.open(QIODevice::ReadOnly));
    const QJsonObject doc = QJsonDocument::fromJson(file.readAll()).object();
    QCOMPARE(doc.value(QStringLiteral("schemaVersion")).toInt(), 1);
    QCOMPARE(doc.value(QStringLiteral("selections")).toObject().value(QStringLiteral("locale"))
                 .toObject().value(QStringLiteral("timezone")).toString(), QStringLiteral("Asia/Tokyo"));
}

void InstallerTest::accountAndPasswordFieldsAreRejected()
{
    for (const char *key : {"password", "rootPassword", "username", "fullName", "mode"}) {
        QString message;
        const QString json = QStringLiteral(R"({"%1":"x"})").arg(QLatin1String(key));
        QVERIFY2(!InstallerCapabilities::submitProposal(json, &message), key);
        QVERIFY(message.contains(QStringLiteral("not proposable")));
    }
}

void InstallerTest::malformedValuesAreRejected()
{
    QString message;
    QVERIFY(!InstallerCapabilities::submitProposal(QStringLiteral("[]"), &message));
    QVERIFY(!InstallerCapabilities::submitProposal(QStringLiteral("{}"), &message));
    QVERIFY(!InstallerCapabilities::submitProposal(QStringLiteral(R"({"filesystem":"ntfs"})"), &message));
    QVERIFY(!InstallerCapabilities::submitProposal(QStringLiteral(R"({"timezone":"../etc"})"), &message));
    QVERIFY(!InstallerCapabilities::submitProposal(QStringLiteral(R"({"applications":"a;rm -rf /"})"), &message));
}

void InstallerTest::stableDiskIdIsAcceptedAndPathTricksAreNot()
{
    QString message;
    QVERIFY(InstallerCapabilities::submitProposal(
        QStringLiteral(R"({"targetDisk":"/dev/disk/by-id/nvme-Samsung_SSD_980_ABC123"})"), &message));
    QVERIFY(!InstallerCapabilities::submitProposal(QStringLiteral(R"({"targetDisk":"/dev/sda; rm"})"), &message));
    QVERIFY(!InstallerCapabilities::submitProposal(QStringLiteral("{\"targetDisk\":\"$(id)\"}"), &message));
}

void InstallerTest::logReturnsTail()
{
    QFile log(m_dir.path() + QStringLiteral("/install.log"));
    QVERIFY(log.open(QIODevice::WriteOnly));
    for (int i = 1; i <= 10; ++i)
        log.write(QByteArray("line ") + QByteArray::number(i) + '\n');
    log.close();
    QString message;
    QVERIFY(InstallerCapabilities::readLog(3, &message));
    QCOMPARE(message, QStringLiteral(R"(["line 8","line 9","line 10"])"));
    QVERIFY(!InstallerCapabilities::readLog(0, &message));
    QVERIFY(!InstallerCapabilities::readLog(500, &message));
}

QTEST_APPLESS_MAIN(InstallerTest)
#include "installer-test.moc"
