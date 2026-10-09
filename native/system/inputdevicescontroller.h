#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
#include <KConfigWatcher>

class InputDevicesController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "InputDevices")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(QVariantMap keyRepeat READ keyRepeat NOTIFY changed)
    Q_PROPERTY(QVariantList keyboardLayouts READ keyboardLayouts NOTIFY changed)
    Q_PROPERTY(QVariantList layoutChoices READ layoutChoices CONSTANT)
    Q_PROPERTY(QVariantList configuredLayouts READ configuredLayouts NOTIFY changed)
    Q_PROPERTY(int activeKeyboardLayout READ activeKeyboardLayout NOTIFY changed)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit InputDevicesController(QObject *parent = nullptr);
    QVariantMap keyRepeat() const;
    Q_INVOKABLE void configureKeyRepeat(const QString &mode, int delay, double rate);
    QVariantList keyboardLayouts() const { return m_keyboardLayouts; }
    QVariantList layoutChoices() const { return m_layoutChoices; }
    QVariantList configuredLayouts() const { return m_configuredLayouts; }
    int activeKeyboardLayout() const { return m_activeKeyboardLayout; }
    Q_INVOKABLE void activateKeyboardLayout(int index);
    Q_INVOKABLE void configureKeyboardLayouts(const QVariantList &ids);
    QVariantList devices() const { return m_devices; }
    bool available() const { return m_available; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setValue(const QString &deviceId, const QString &property, const QVariant &value);
Q_SIGNALS:
    void changed();
private Q_SLOTS:
    void scheduleRefresh();
private:
    void refreshKeyboardLayouts();
    QVariantList m_devices, m_keyboardLayouts, m_layoutChoices, m_configuredLayouts;
    int m_activeKeyboardLayout = -1;
    bool m_available = false, m_busy = false;
    QString m_error;
    QTimer m_refreshTimer;
    KConfigWatcher::Ptr m_inputWatcher;
    int m_generation = 0;
    int m_keyboardGeneration = 0;
};
