// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <KCModule>

class QSpinBox;
class QDoubleSpinBox;

namespace MeoDecoration {

class ConfigWidget final : public KCModule
{
    Q_OBJECT
public:
    ConfigWidget(QObject *parent, const KPluginMetaData &data, const QVariantList &args);

    void load() override;
    void save() override;
    void defaults() override;

private:
    void writeSettings(bool defaults);
    QSpinBox *m_titlebarHeight;
    QSpinBox *m_buttonSlot;
    QSpinBox *m_buttonSpacing;
    QSpinBox *m_cornerRadius;
    QSpinBox *m_hoverDiameter;
    QDoubleSpinBox *m_shadowStrength;
    QSpinBox *m_shadowSize;
    QSpinBox *m_shadowOffsetY;
    QSpinBox *m_hoverDuration;
    QSpinBox *m_focusDuration;
};

} // namespace MeoDecoration
