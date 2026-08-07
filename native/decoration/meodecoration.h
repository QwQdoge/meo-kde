#pragma once

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecorationShadow>
#include <KColorScheme>
#include <QColor>
#include <memory>

namespace MeoDecoration {

struct ConfigSettings {
    int titleBarHeight = 36;
    int cornerRadius = 14;
    int buttonDiameter = 13;
    int buttonHitSize = 26;
    int buttonSpacing = 7;
    int buttonRightMargin = 14;
    bool showButtonBackground = true;
    double shadowIntensity = 0.25;
    int shadowRadius = 24;
    int shadowOffsetY = 4;
    bool alignTitleCenter = true;
    bool squareMaximized = true;
    bool enableAccentTint = true;
};

class Decoration : public KDecoration3::Decoration {
    Q_OBJECT
public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());
    ~Decoration() override;

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintRegion) override;

    const ConfigSettings &config() const { return m_config; }
    QColor titleBarBackgroundColor() const;
    QColor titleTextColor() const;

    bool isWindowActive() const;
    bool isWindowMaximized() const;

private:
    void loadConfig();
    void updateLayout();
    void updateShadow();
    void createButtons();

    ConfigSettings m_config;
    KDecoration3::DecorationButtonGroup *m_rightButtonGroup = nullptr;
    std::shared_ptr<KDecoration3::DecorationShadow> m_shadow;
};

} // namespace MeoDecoration
