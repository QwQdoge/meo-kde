#pragma once

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecorationShadow>
#include <KColorScheme>
#include <QColor>
#include <memory>

class QVariantAnimation;

namespace MeoDecoration {

class Button;

struct ConfigSettings {
    int titleBarHeight = 32;
    int cornerRadius = 12;
    int buttonDiameter = 20;
    int buttonHitSize = 32;
    int buttonSpacing = 0;
    int buttonRightMargin = 4;
    bool showButtonBackground = true;
    double shadowIntensity = 0.18;
    int shadowRadius = 28;
    int shadowOffsetY = 6;
    int hoverInDuration = 100;
    int hoverOutDuration = 80;
    int focusTransitionDuration = 180;
    int rippleDuration = 180;
    bool alignTitleCenter = true;
    bool squareMaximized = true;
    bool enableAccentTint = false;
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
    qreal captionIconOpacity() const;
    qreal captionTitleOpacity() const;

private:
    void loadConfig();
    void updateLayout();
    void updateShadow();
    void createButtons();
    void updateFocusAnimation(bool active);

    ConfigSettings m_config;
    KDecoration3::DecorationButtonGroup *m_rightButtonGroup = nullptr;
    std::shared_ptr<KDecoration3::DecorationShadow> m_shadow;
    QVariantAnimation *m_focusAnimation = nullptr;
    qreal m_focusProgress = 1.0;
};

} // namespace MeoDecoration
