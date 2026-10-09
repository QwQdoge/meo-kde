#pragma once
#include <QObject>
#include <QVariantList>
#include <QStringList>
#include <QTimer>

class InputMethodController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "InputMethods")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QStringList groups READ groups NOTIFY changed)
    Q_PROPERTY(QString currentGroup READ currentGroup NOTIFY changed)
    Q_PROPERTY(QString currentMethod READ currentMethod NOTIFY changed)
    Q_PROPERTY(QVariantList methods READ methods NOTIFY changed)
    Q_PROPERTY(QVariantList configuredMethods READ configuredMethods NOTIFY changed)
public:
    explicit InputMethodController(QObject *parent = nullptr);
    bool available() const { return m_available; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QStringList groups() const { return m_groups; }
    QString currentGroup() const { return m_group; }
    QString currentMethod() const { return m_current; }
    QVariantList methods() const { return m_methods; }
    QVariantList configuredMethods() const { return m_configured; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void selectGroup(const QString &group);
    Q_INVOKABLE void activateMethod(const QString &id);
    Q_INVOKABLE void configureMethods(const QVariantList &ids);
Q_SIGNALS:
    void changed();
private Q_SLOTS:
    void scheduleRefresh();
private:
    bool m_available = false, m_busy = false;
    QString m_error, m_group, m_current, m_layout;
    QStringList m_groups;
    QVariantList m_methods, m_configured;
    QTimer m_refreshTimer;
    int m_generation = 0;
    void performRequest(const QString &method, const QVariantList &arguments);
};
