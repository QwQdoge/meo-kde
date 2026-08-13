// SPDX-License-Identifier: GPL-3.0-or-later
#include "meodecorationconfig.h"

#include <KConfigGroup>
#include <KPluginFactory>
#include <KSharedConfig>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QSpinBox>

namespace MeoDecoration {
K_PLUGIN_CLASS_WITH_JSON(ConfigWidget, "kcm_meodecoration.json")

namespace {
QSpinBox *spin(QFormLayout *layout, const QString &label, int minimum, int maximum)
{
    auto *control = new QSpinBox;
    control->setRange(minimum, maximum);
    control->setSuffix(QStringLiteral(" px"));
    layout->addRow(label, control);
    return control;
}
}

ConfigWidget::ConfigWidget(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : KCModule(parent, data)
{
    Q_UNUSED(args)
    auto *layout = new QFormLayout(widget());
    m_titlebarHeight = spin(layout, tr("Titlebar height"), 26, 42);
    m_buttonSlot = spin(layout, tr("Button slot size"), 26, 40);
    m_buttonSpacing = spin(layout, tr("Button spacing"), 0, 6);
    m_cornerRadius = spin(layout, tr("Window corner radius"), 0, 20);
    m_hoverDiameter = spin(layout, tr("Hover circle size"), 16, 32);
    m_shadowSize = spin(layout, tr("Shadow size"), 8, 48);
    m_shadowOffsetY = spin(layout, tr("Shadow vertical offset"), -4, 16);
    m_hoverDuration = spin(layout, tr("Hover duration"), 0, 300);
    m_focusDuration = spin(layout, tr("Focus transition"), 0, 400);
    m_shadowStrength = new QDoubleSpinBox;
    m_shadowStrength->setRange(0.0, 100.0);
    m_shadowStrength->setDecimals(0);
    m_shadowStrength->setSuffix(QStringLiteral(" %"));
    layout->addRow(tr("Shadow strength"), m_shadowStrength);

    const auto controls = findChildren<QAbstractSpinBox *>();
    for (auto *control : controls) {
        connect(control, &QAbstractSpinBox::editingFinished, this, [this] { markAsChanged(); });
    }
    load();
}

void ConfigWidget::load()
{
    const KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("kwinrc")), QStringLiteral("org.meo.decoration"));
    m_titlebarHeight->setValue(group.readEntry("TitleBarHeight", 32));
    m_buttonSlot->setValue(group.readEntry("ButtonHitSize", 32));
    m_buttonSpacing->setValue(group.readEntry("ButtonSpacing", 0));
    m_cornerRadius->setValue(group.readEntry("CornerRadius", 10));
    m_hoverDiameter->setValue(group.readEntry("ButtonDiameter", 22));
    m_shadowSize->setValue(group.readEntry("ShadowRadius", 24));
    m_shadowOffsetY->setValue(group.readEntry("ShadowOffsetY", 6));
    m_shadowStrength->setValue(group.readEntry("ShadowIntensity", 0.22) * 100.0);
    m_hoverDuration->setValue(group.readEntry("HoverInDuration", 100));
    m_focusDuration->setValue(group.readEntry("FocusTransitionDuration", 180));
    setNeedsSave(false);
}

void ConfigWidget::writeSettings(bool useDefaults)
{
    KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("kwinrc")), QStringLiteral("org.meo.decoration"));
    group.writeEntry("TitleBarHeight", useDefaults ? 32 : m_titlebarHeight->value());
    group.writeEntry("ButtonHitSize", useDefaults ? 32 : m_buttonSlot->value());
    group.writeEntry("ButtonSpacing", useDefaults ? 0 : m_buttonSpacing->value());
    group.writeEntry("CornerRadius", useDefaults ? 10 : m_cornerRadius->value());
    group.writeEntry("ButtonDiameter", useDefaults ? 22 : m_hoverDiameter->value());
    group.writeEntry("ShadowRadius", useDefaults ? 24 : m_shadowSize->value());
    group.writeEntry("ShadowOffsetY", useDefaults ? 6 : m_shadowOffsetY->value());
    group.writeEntry("ShadowIntensity", (useDefaults ? 22.0 : m_shadowStrength->value()) / 100.0);
    group.writeEntry("HoverInDuration", useDefaults ? 100 : m_hoverDuration->value());
    group.writeEntry("HoverOutDuration", useDefaults ? 80 : m_hoverDuration->value());
    group.writeEntry("FocusTransitionDuration", useDefaults ? 180 : m_focusDuration->value());
    group.sync();
}

void ConfigWidget::save()
{
    writeSettings(false);
    QDBusConnection::sessionBus().send(QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"), QStringLiteral("org.kde.KWin"), QStringLiteral("reconfigure")));
    setNeedsSave(false);
}

void ConfigWidget::defaults()
{
    m_titlebarHeight->setValue(32); m_buttonSlot->setValue(32); m_buttonSpacing->setValue(0);
    m_cornerRadius->setValue(10); m_hoverDiameter->setValue(22); m_shadowSize->setValue(24);
    m_shadowOffsetY->setValue(6); m_shadowStrength->setValue(22); m_hoverDuration->setValue(100); m_focusDuration->setValue(180);
    markAsChanged();
}

} // namespace MeoDecoration

#include "meodecorationconfig.moc"
